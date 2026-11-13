# Helm Chart for CodeTogether AI

## Summary

This chart deploys CodeTogether AI on a Kubernetes cluster using Helm. Runtime
configuration is supplied as `ctai-configuration.properties`, and the protected
storage master key is stored in a separate Kubernetes Secret.

## Prerequisites

- Helm v3.5+
- Kubernetes v1.19+
- PostgreSQL reachable from the cluster. This chart does not install Postgres.
- A DNS-routable HTTPS host for CodeTogether AI, configured as `service_fqdn`.
- A TLS Secret for Ingress when `ingress.enabled=true`.
- Or, instead of an Ingress controller, Gateway API CRDs and a `Gateway` when
  `gateway.enabled=true` (see "Gateway API" below).
- CodeTogether-provided credentials for `hub.edge.codetogether.com`.

## PostgreSQL Prerequisites

This chart does not install Postgres. Provide an external database reachable
from the cluster and configure it in `ctai-configuration.properties`.

Before the first pod starts, run the database grants as a Postgres admin. A
dedicated application user is recommended:

```sql
GRANT ALL PRIVILEGES ON DATABASE <db> TO <app_user>;
GRANT CREATE ON DATABASE <db> TO <app_user>;
ALTER DATABASE <db> OWNER TO <app_user>;
ALTER ROLE <app_user> BYPASSRLS;
```

`BYPASSRLS` matches the production application role shape. CodeTogether uses
row-level security on platform tables, including `oauth2_cache`, where SSO
stores OAuth state. Without it, SSO redirects can fail because OAuth state
cannot be inserted or read.

Managed Postgres superusers, such as DigitalOcean's `doadmin`, bypass RLS but
are not recommended for production application connections. If your provider
requires SSL, append `?sslmode=require` to the JDBC URL, for example:

```properties
database_url=jdbc:postgresql://postgres.example.internal:5432/codetogether?sslmode=require
```

## Install

### 1. Prepare the configuration file

Copy `ctai-configuration.properties.template` to
`ctai-configuration.properties`, then replace the example values with the values
for your environment.

```bash
cp ctai-configuration.properties.template ctai-configuration.properties
```

Set `service_fqdn` to the public HTTPS URL for the deployment, for example:

```properties
service_fqdn=https://ai.example.com
```

Set the external Postgres connection properties:

```properties
database_url=jdbc:postgresql://postgres.example.internal:5432/codetogether
database_username=codetogether
database_password=replace-with-postgres-password
```

Generate the random properties-file secrets and paste the output into
`ctai-configuration.properties`:

```bash
./generate-properties-secrets.sh
```

The configuration file contains deployment secrets. Store it securely and do
not commit customer-specific values.

### 2. Configure SSO

Register this redirect URI with your identity provider:

```text
https://ai.example.com/api/v1/auth/sso/provider/callback
```

Use the same host as `service_fqdn`. For Google OAuth or Google OIDC, add that
URI as an Authorized redirect URI in the Google Cloud Console, then set the
provider values in `ctai-configuration.properties`, for example:

```properties
sso_provider1_type=google
sso_provider1=google
sso_provider1_client_id=replace-with-google-client-id
sso_provider1_client_secret=replace-with-google-client-secret
sso_provider1_client_issuer_url=https://accounts.google.com
```

Before testing SSO, complete the [PostgreSQL prerequisites](#postgresql-prerequisites).

### 3. Create the TLS Secret

Create the TLS Secret in the namespace where CodeTogether AI will run. The
default Secret name is `codetogether-ai-tls`.

```bash
kubectl create namespace codetogether-ai
kubectl create secret tls codetogether-ai-tls \
  --namespace codetogether-ai \
  --key /path/to/tls.key \
  --cert /path/to/tls.crt
```

### 4. Create the protected storage master-key Secret

CodeTogether AI uses a 32-byte AES master key to encrypt sensitive values stored
in Postgres. Generate this key once per deployment environment and database.
Changing the key after encrypted data exists prevents that data from being
decrypted.

```bash
./generate-master-key.sh --k8s-secret-yaml --secret-name ctai-master-key \
  > ctai-master-key-secret.yaml

kubectl apply -f ctai-master-key-secret.yaml -n codetogether-ai
```

Save the generated base64 key in your password manager and keep it with your
Postgres backup procedure.

### 5. Install the chart

```bash
helm repo add codetogether https://helm.codetogether.io
helm repo update

helm install codetogether-ai codetogether/codetogether-ai \
  --namespace codetogether-ai --create-namespace \
  --set-file ctaiPropertiesFile=./ctai-configuration.properties \
  --set imageCredentials.username=replace-with-hub-edge-username \
  --set imageCredentials.password=replace-with-hub-edge-password \
  --set masterKey.source=secret \
  --set masterKey.existingSecret=ctai-master-key
```

Ingress host and TLS are derived from `service_fqdn` in
`ctai-configuration.properties`. If you also set `service.fqdn` in Helm values,
it must exactly match `service_fqdn`.

By default, the chart does not set `ingress.className`, matching the
CodeTogether Intel chart. Clusters without a default IngressClass should set one
explicitly:

```bash
--set ingress.className=nginx
```

If you set `ingress.className=codetogether-nginx`, the chart also creates a
matching `IngressClass`.

### Gateway API (NGINX Gateway Fabric)

Clusters that route with Gateway API instead of an Ingress controller (for
example NGINX Gateway Fabric, which replaces the retired ingress-nginx) can have
the chart attach an `HTTPRoute` to an existing `Gateway`:

```yaml
ingress:
  enabled: false
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway        # your Gateway
      namespace: gateway-system   # omit if it is in the release namespace
      sectionName: https          # the HTTPS listener with the certificate
```

The chart renders:

- an `HTTPRoute` for the `service_fqdn` host, `/` to the chart Service;
- with NGINX Gateway Fabric, a `ClientSettingsPolicy` that raises the request
  body limit to `16m` (`gateway.nginxGatewayFabric.clientSettingsPolicy`). It
  replaces the Ingress annotation `nginx.ingress.kubernetes.io/proxy-body-size`;
  without it, tracker uploads over 1MB fail with 413. With `enabled: auto` it is
  rendered only when the cluster serves that API. For another Gateway API
  implementation, set the equivalent limit on your side.

#### ListenerSet: your own listener on a shared Gateway

Instead of adding a listener to the shared `Gateway` for this host, the chart
can create a `ListenerSet` (`gateway.networking.k8s.io/v1`, Gateway API v1.5+)
that adds the HTTPS listener for the `service_fqdn` host, with its certificate,
from the release namespace. The `HTTPRoute` then attaches to that ListenerSet, so leave
`gateway.parentRefs` empty:

```yaml
ingress:
  enabled: false
gateway:
  enabled: true
  listenerSet:
    enabled: true
    parentRef:
      name: gateway-ngf          # the shared Gateway
      namespace: kube-system
    # The listener's hostname is the service_fqdn host. The certificate Secret
    # defaults to <release fullname>-tls; set listenerSet.tlsSecretName to change it.
    annotations:
      cert-manager.io/cluster-issuer: cert-manager-clusterissuer
```

The shared Gateway has to accept ListenerSets from the release namespace
(`spec.allowedListeners.namespaces`). With a cert-manager version that supports
ListenerSets, the issuer annotation on the ListenerSet issues the certificate
into that Secret; otherwise create the Secret yourself. On cert-manager v1.21
that support is off by default; enable it in the cert-manager chart values:

```yaml
config:
  apiVersion: controller.config.cert-manager.io/v1alpha1
  kind: ControllerConfiguration
  enableGatewayAPI: true
  enableGatewayAPIListenerSet: true
featureGates: ListenerSets=true
```

Without it, cert-manager logs `skipping disabled controller ... listenerset` and
no certificate is issued.

If you already applied a ListenerSet with the same name by hand, Helm refuses to
take it over. Let Helm adopt it before the upgrade:

```bash
kubectl -n <namespace> label listenerset <release-fullname> app.kubernetes.io/managed-by=Helm
kubectl -n <namespace> annotate listenerset <release-fullname> \
  meta.helm.sh/release-name=<release> meta.helm.sh/release-namespace=<namespace>
```

The chart doesn't create the `Gateway`, and without a ListenerSet it doesn't
create listeners or certificates either. On the Gateway side, check that:

- the listener allows routes from the release namespace
  (`allowedRoutes.namespaces`);
- the listener can read its certificate Secret. A Secret in another namespace
  needs a `ReferenceGrant` there.
- the route is accepted:
  `kubectl get httproute <release-fullname> -o jsonpath='{.status.parents[*].conditions}'`
  (the install notes print the exact command).

### Client IP addresses

`clientIp.trustedProxyHops` (default `2`: Ingress controller or Gateway, plus the
nginx in the pod) tells the server how many proxies in front of the pod append
to `X-Forwarded-For`. Add one for each extra proxy in front (load balancer, WAF,
corporate proxy). Set it to exactly the proxies you control: too low records a
proxy's address, and too high can record an address the client put in its own
`X-Forwarded-For` when your outermost proxy keeps that header. A
`CTAI_INGEST_OTEL_TRUSTED_PROXY_HOPS` entry in `extraEnvVars` takes precedence.

## Configuration

The following table lists the primary configurable parameters and defaults.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `nameOverride` | Overrides the chart name | `""` |
| `fullnameOverride` | Overrides the full release name | `""` |
| `image.repository` | Container image repository | `hub.edge.codetogether.com/releases/codetogether-ai` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.tag` | Container image tag | `latest` |
| `image.digest` | Optional image digest; overrides the tag when set | `""` |
| `imageCredentials.enabled` | Create a pull Secret from registry credentials | `true` |
| `imageCredentials.registry` | Private registry host | `hub.edge.codetogether.com` |
| `imageCredentials.username` | Registry username | `my-customer-username` |
| `imageCredentials.password` | Registry password | `my-customer-password` |
| `service.fqdn` | Public HTTPS URL; optional with `--set-file`, required for pre-created properties Secrets | `""` |
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.port` | Service port for nginx / portal | `1080` |
| `service.annotations` | Kubernetes Service annotations | `{}` |
| `ctaiPropertiesFile` | Properties file contents, normally set with `--set-file` | `""` |
| `ctaipropertiessecret.enabled` | Mount a pre-created properties Secret instead of creating one from `ctaiPropertiesFile` | `false` |
| `ctaipropertiessecret.ref` | Name of the pre-created properties Secret | `""` |
| `masterKey.source` | Master key source: `secret`, `auto`, or `external` | `secret` |
| `masterKey.existingSecret` | Pre-created master-key Secret name when `source=secret` | `ctai-master-key` |
| `masterKey.existingSecretKey` | Key in the master-key Secret | `CTAI_PROTECTED_STORAGE_MASTER_KEY_B64` |
| `masterKey.existingSecretVersionKey` | Optional version key in the master-key Secret | `CTAI_PROTECTED_STORAGE_MASTER_KEY_VERSION` |
| `properties.mountPath` | Pod mount path for the properties file | `/opt/ctai/server/config` |
| `properties.fileName` | Properties filename inside the Secret | `ctai-configuration.properties` |
| `ingress.enabled` | Create an Ingress resource | `true` |
| `ingress.annotations` | Ingress annotations | `nginx.ingress.kubernetes.io/proxy-body-size: "16m"` |
| `ingress.tls.secretName` | TLS Secret for Ingress | `codetogether-ai-tls` |
| `gateway.enabled` | Create a Gateway API `HTTPRoute` | `false` |
| `gateway.parentRefs` | Gateway(s) the `HTTPRoute` attaches to; required when enabled unless `gateway.listenerSet.enabled` | `[]` |
| `gateway.annotations` / `gateway.labels` | Extra `HTTPRoute` metadata (`labels` also go on the `ListenerSet`) | `{}` |
| `gateway.nginxGatewayFabric.clientSettingsPolicy.enabled` | NGINX Gateway Fabric body-size policy: `auto`, `true` or `false` | `auto` |
| `gateway.nginxGatewayFabric.clientSettingsPolicy.bodyMaxSize` | Request body limit on the Gateway | `16m` |
| `gateway.listenerSet.enabled` | Create a `ListenerSet` with this release's HTTPS listener; the `HTTPRoute` attaches to it when `gateway.parentRefs` is empty. Requires `gateway.enabled=true` | `false` |
| `gateway.listenerSet.parentRef` | The shared Gateway (`name`, `namespace`); required when enabled | `{}` |
| `gateway.listenerSet.listenerName` / `port` | Listener name (the route's `sectionName`) and port | `https` / `443` |
| `gateway.listenerSet.tlsSecretName` | TLS Secret for the listener | `<release fullname>-tls` |
| `gateway.listenerSet.annotations` | `ListenerSet` annotations (e.g. the cert-manager issuer); labels come from `gateway.labels` | `{}` |
| `clientIp.trustedProxyHops` | Proxies in front of the pod that append to `X-Forwarded-For` | `2` |
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name | `codetogether-ai` |
| `replicaCount` | Deployment replica count | `1` |
| `readinessProbe.path` | Readiness endpoint on port 1080 | `/healthz` |
| `livenessProbe.path` | Liveness endpoint on port 8080 | `/actuator/health` |
| `startupProbe.enabled` | Enable startup probe | `true` |
| `securityContext.readOnlyRootFilesystem` | Run with a read-only root filesystem; the container writes only to `writableDirectories`. See [Read-only root filesystem](#read-only-root-filesystem) | `true` |
| `writableDirectories.<name>.enabled` | Mount an `emptyDir` on that directory (`runtime`, `www`, `logs`, `tmp`, `systemTmp`); `false` to mount your own volume there | `true` |
| `writableDirectories.<name>.sizeLimit` | Optional `emptyDir` size limit (for example `2Gi`); the pod is evicted when it is exceeded | `""` |

`image.tag` controls which container image the Deployment pulls at install or
upgrade time. `appVersion` in `Chart.yaml` is chart metadata only; it does not
pin the running image unless you set `image.tag` or `image.digest`. Most
installations can use the default `latest` tag and receive hub.edge updates on
`helm upgrade` after the registry tag moves.

## Pre-Created Properties Secret

For GitOps workflows, create and manage the properties Secret outside Helm:

```bash
kubectl create secret generic ctai-properties \
  --namespace codetogether-ai \
  --from-file=ctai-configuration.properties=./ctai-configuration.properties
```

Then install or upgrade with:

```yaml
ctaipropertiessecret:
  enabled: true
  ref: ctai-properties

service:
  fqdn: https://ai.example.com
```

When Helm cannot read the properties file through `--set-file`, `service.fqdn`
is required for Ingress and install notes. It must match `service_fqdn` inside
the Secret.

## Validation and Troubleshooting

Render the chart locally before installing:

```bash
helm template codetogether-ai codetogether/codetogether-ai \
  --set-file ctaiPropertiesFile=./ctai-configuration.properties \
  --set service.fqdn=https://ai.example.com \
  --set imageCredentials.username=test \
  --set imageCredentials.password=test
```

`service.fqdn` must match `service_fqdn` in the properties file when both are set.

At runtime, CodeTogether AI validates the mounted configuration before the
service starts. If validation fails, the pod exits and logs a block beginning
with `Configuration errors:`.

```bash
kubectl logs -n codetogether-ai deploy/codetogether-ai
kubectl logs -n codetogether-ai deploy/codetogether-ai --previous
```

Common causes include unfilled example values, Postgres connectivity problems,
missing or changed master-key Secret, an HTTP `service_fqdn`, missing TLS
Secret, or SSO provider settings that do not match the registered redirect URI.
If login fails after returning from Google or another identity provider with
`authorization_request_not_found`, check that the database user has `BYPASSRLS`
and that the registered OAuth redirect URI exactly matches
`{service_fqdn}/api/v1/auth/sso/provider/callback`.

### What the container image contains

The image is built on [Wolfi](https://github.com/wolfi-dev), a minimal Linux
distribution, and runs as the non-root user `ctai` (uid and gid `2200`).

- Shell and tools: `bash`, BusyBox `sh` (`/bin/sh`), `curl`, `ps`, `top`,
  `ping`, `netstat`, `vi`, `less`, and the GNU core utilities. `ss`, `ip`,
  `openssl` and `dig` are not included.
- Java: OpenJDK 25 with its tools (`jcmd`, `jstack`, `jmap`, `jfr`,
  `keytool`). `JAVA_HOME` is `/usr/lib/jvm/default-jvm`, and the JDK's trust
  store is `/etc/ssl/certs/java/cacerts`.
- Packages: the package manager is `apk`. It needs root, so it cannot install
  anything in the running container. An image built `FROM` this one installs
  packages with `apk add` as root before switching back to `USER 2200`.

### Inspect a running pod

`kubectl exec` is enough for the tools above:

```bash
kubectl exec -it -n codetogether-ai deploy/codetogether-ai -c codetogether-ai -- bash
```

For a tool the image does not have, attach an ephemeral debug container. It
shares the application's process namespace and network, so it sees the Java
process, its files under `/proc/<pid>/root` and `localhost`, and nothing
restarts. Use kubectl 1.32 or later, and any image your cluster can pull:

```bash
POD=$(kubectl get pod -n codetogether-ai -l app.kubernetes.io/name=codetogether-ai -o name | head -1)
kubectl debug -it -n codetogether-ai "$POD" \
  --image=<a debugging image> \
  --target=codetogether-ai --profile=general -c debug -- sh
```

If the namespace enforces the Pod Security `restricted` profile, which does not
allow a root debug container, use the CodeTogether AI image itself as the debug
image and run it as the application's user. The image names its user (`ctai`),
so the numeric uid has to be given:

```bash
echo '{"securityContext":{"runAsUser":2200,"runAsGroup":2200}}' > uid2200.json
IMAGE=$(kubectl get "$POD" -n codetogether-ai -o jsonpath='{.spec.containers[0].image}')
kubectl debug -it -n codetogether-ai "$POD" --image="$IMAGE" \
  --target=codetogether-ai --profile=restricted --custom=uid2200.json \
  -c debug-app -- bash
```

An ephemeral container stays in the pod's spec until the pod is replaced, and
each one needs a new name (`-c`). The process environment and the mounted
properties file contain secrets: do not paste them into tickets or chat.

### Read-only root filesystem

From chart 0.2.5 the container runs with `readOnlyRootFilesystem: true`: the
image's binaries, scripts and configuration cannot be changed from inside the
pod. It writes only to these directories, each an `emptyDir` that lives as long
as the pod (`writableDirectories`):

| Name | Path | What |
|---|---|---|
| `runtime` | `/opt/ctai/runtime` | Artifacts unpacked at start with the server URL injected into the IDE plugins (about 200 MB), and the YAML generated from the properties file (`config/ctai-configuration.yml`) |
| `www` | `/opt/ctai/www` | nginx's document root: the portal and metric lineage |
| `logs` | `/opt/ctai/logs` | `server.log`, the nginx logs, heap dumps (the newest is kept) |
| `tmp` | `/opt/ctai/tmp` | nginx's pid file and temp files |
| `systemTmp` | `/tmp` | JVM and Tomcat temp files |

A container restart keeps them, and reuses the unpacked artifacts; a new pod
starts empty. To keep logs on a volume of your own, turn that directory over to
it:

```yaml
writableDirectories:
  logs:
    enabled: false
extraVolumes:
  - name: ctai-logs
    persistentVolumeClaim:
      claimName: ctai-logs
extraVolumeMounts:
  - name: ctai-logs
    mountPath: /opt/ctai/logs
```

The chart refuses:
- a volume in `extraVolumeMounts` on a path a writable directory already mounts;
- a disabled writable directory with no volume of yours on its path, which would be read-only;
- two writable directories on one path;
- `readOnlyRootFilesystem` as a string (`"true"` or `"false"`): it must be a boolean.

Paths are compared after cleaning, so `/opt/ctai/logs/` is `/opt/ctai/logs`.

**When the previous layout is used.** With the previous layout there are no
`writableDirectories`, and the container writes to its own layer. The chart
uses it:
- when `securityContext.readOnlyRootFilesystem` is `false`. Set that if a
  pre-start hook (`/opt/ctai/hooks/pre-start.d`) writes outside these
  directories.
- when `image.tag` (or `appVersion`, when the tag is empty) names an image
  older than the first one that supports a read-only root filesystem. Older
  images crash-loop under it. `helm install` prints a warning when this
  happens. A tag that is not a version, such as `latest`, or an `image.digest`,
  is taken as supporting it.
- after `helm upgrade --reuse-values` from a chart before 0.2.5, whose values
  have no `readOnlyRootFilesystem`. Add
  `--set securityContext.readOnlyRootFilesystem=true` to turn it on.

**Upgrading from 0.2.4 with a volume of your own on one of these paths** (for
example a PVC on `/opt/ctai/logs` in `extraVolumeMounts`): `helm upgrade` stops
with "extraVolumeMounts mounts /opt/ctai/logs, which writableDirectories.logs
already mounts". Add `--set writableDirectories.logs.enabled=false` (or the
same in your values file) and run it again; your volume keeps that path.

## Upgrade

```bash
helm repo update
helm upgrade codetogether-ai codetogether/codetogether-ai \
  --namespace codetogether-ai \
  --set-file ctaiPropertiesFile=./ctai-configuration.properties \
  --set imageCredentials.username=replace-with-hub-edge-username \
  --set imageCredentials.password=replace-with-hub-edge-password
```

Using `latest` is fine for most installs. Pin a known GA build only when change
control requires a fixed container version:

```bash
helm upgrade codetogether-ai codetogether/codetogether-ai \
  --namespace codetogether-ai \
  --set-file ctaiPropertiesFile=./ctai-configuration.properties \
  --set imageCredentials.username=replace-with-hub-edge-username \
  --set imageCredentials.password=replace-with-hub-edge-password \
  --set image.tag=0.1.1204
```

The Deployment rolls when the chart-managed properties Secret changes.

### Rollout strategy

From chart 0.2.4 the Deployment stops the old pod before it starts the new one
(`deploymentStrategy`: `RollingUpdate` with `maxSurge: 0`, `maxUnavailable: 1`).
On a single replica an upgrade therefore has a short outage while the new pod
starts. Earlier charts used the Kubernetes default, which starts the new pod
first.

The pods of one release share an embedded Hazelcast cluster, and a pod only
joins a cluster that runs its own Hazelcast minor version. When a release
changes that version (the release notes say so), any old pod still running
makes the new pod fail to join: its container exits and restarts in a loop, and
the rollout never completes while the old pods keep serving. `helm upgrade`
without `--wait` still prints `deployed`; `kubectl rollout status` shows the
stall.

- **One replica:** the default strategy handles it, as long as the release was
  upgraded to chart 0.2.4 or later. Upgrade the chart and the image in the same
  `helm upgrade`, as above.
- **More than one replica:** upgrade across a Hazelcast version with
  `Recreate`, which stops every old pod first (a short outage):

  ```bash
  helm upgrade codetogether-ai codetogether/codetogether-ai \
    --namespace codetogether-ai \
    --reset-then-reuse-values \
    --set deploymentStrategy.type=Recreate \
    --set deploymentStrategy.rollingUpdate=null
  ```

  `rollingUpdate=null` is required: Helm merges overrides into the existing
  values, and Kubernetes rejects `Recreate` while `rollingUpdate` is set. The
  same command completes a rollout that has already stalled.
  `--reset-then-reuse-values` keeps `Recreate` for later upgrades; to return to
  the default on a later upgrade, add (Helm 3.10 or later)
  `--set-json 'deploymentStrategy={"type":"RollingUpdate","rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}'`.

If a rollout has already stalled on a chart older than 0.2.4, switch the
Deployment to `Recreate` directly:

```bash
kubectl -n codetogether-ai patch deployment codetogether-ai \
  -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
```

## Uninstall

```bash
helm uninstall codetogether-ai -n codetogether-ai
```
