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
- CodeTogether-provided credentials for `hub.edge.codetogether.com`.

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
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name | `codetogether-ai` |
| `replicaCount` | Deployment replica count | `1` |
| `readinessProbe.path` | Readiness endpoint on port 1080 | `/healthz` |
| `livenessProbe.path` | Liveness endpoint on port 8080 | `/actuator/health` |
| `startupProbe.enabled` | Enable startup probe | `true` |

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

## Uninstall

```bash
helm uninstall codetogether-ai -n codetogether-ai
```
