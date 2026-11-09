# README.md Helm Chart for CodeTogether Collab

## Summary

This chart creates a CodeTogether Collab server deployment on a Kubernetes cluster using the Helm package manager.

## Prerequisites

This chart has been created with Helm v3 and tested with:

- Kubernetes v1.18+
- Helm v3.5+

With `gateway.enabled=true` (see [Gateway API](#gateway-api-nginx-gateway-fabric)),
the cluster also needs the Gateway API CRDs (v1.5+ for the ListenerSet) and a
`Gateway`, for example from NGINX Gateway Fabric.

## Configuration

The following table lists configurable parameters of the CodeTogether Collab chart and their default values:

| Parameter                                   | Description                                                                                     | Default                                                   |
|---------------------------------------------|-------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `nameOverride`                              | Overrides the name of the chart                                                                | `""`                                                     |
| `fullnameOverride`                          | Overrides the full name of the chart                                                           | `""`                                                     |
| `image.repository`                          | Docker image repository for CodeTogether Collab                                                | `codetogether/codetogether-collab`                       |
| `image.pullPolicy`                          | Container image pull policy                                                                    | `Always`                                                  |
| `image.tag`                                 | Tag for the CodeTogether Collab image                                                          | `latest`                                                  |
| `imageCredentials.enabled`                  | Enables authentication for private Docker registry                                             | `false`                                                   |
| `imageCredentials.registry`                 | Docker registry URL                                                                            | `hub.edge.codetogether.com`                               |
| `imageCredentials.username`                 | Docker registry username                                                                       | `my-customer-username`                                    |
| `imageCredentials.password`                 | Docker registry password                                                                       | `my-customer-password`                                    |
| `imageCredentials.email`                    | Docker registry email                                                                          | `unused`                                                  |
| `openshift.enabled`                         | Enables deployment in OpenShift                                                                | `false`                                                   |
| `intel.url`                                 | URL of the Intel server                                                                        | `https://your-intel-server`                               |
| `intel.secret`                             | Secret key used to authenticate with the Intel server for secure communication                | `SECRET`                                                  |
| `codetogether.mode`                         | CodeTogether running mode (`direct`, `locator-central`, or `locator-edge`)                     | `direct`                                                  |
| `codetogether.url`                          | Fully Qualified Domain Name (FQDN) for the server                                              | `https://codetogether.local`                              |
| `codetogether.trustAllCerts`                | Allows untrusted certificates if set to `true`                                                | `true`                                                    |
| `codetogether.noclients`                    | Disables the `/clients` endpoint if set to `true`                                              | `false`                                                   |
| `codetogether.timeZone.enabled`             | Enables a customized time zone for the container                                               | `false`                                                   |
| `codetogether.timeZone.region`              | Time zone region for the container                                                             | `America/Chicago`                                         |
| `locatorCentral.database.host`              | Host for locator-central database                                                              | `10.10.0.2`                                               |
| `locatorCentral.database.port`              | Port for locator-central database                                                              | `3306`                                                    |
| `locatorCentral.database.schema`            | Schema name for locator-central database                                                      | `codetogether`                                            |
| `locatorCentral.database.dialect`           | Database dialect (`mysql` or `postgres`)                                                      | `mysql`                                                   |
| `locatorCentral.database.user`              | Username for the database                                                                      | `my-db-username`                                          |
| `locatorCentral.database.password`          | Password for the database                                                                      | `my-db-password`                                          |
| `locatorCentral.database.sslEnabled`        | Enables SSL for the database connection                                                       | `false`                                                   |
| `locatorEdge.locator`                       | URL of the locator for edge mode                                                              | `https://codetogether.locator`                            |
| `locatorEdge.region`                        | Region for the edge server                                                                     | `default`                                                 |
| `ingress.enabled`                           | Enables ingress controller resource                                                           | `true`                                                    |
| `ingress.tls.secretName`                    | TLS secret name for ingress                                                                   | `codetogether-tls`                                        |
| `gateway.enabled`                           | Creates a Gateway API `HTTPRoute` for the `codetogether.url` host                              | `false`                                                   |
| `gateway.parentRefs`                        | Gateway(s) the `HTTPRoute` attaches to; required when enabled unless `gateway.listenerSet.enabled` | `[]`                                                  |
| `gateway.annotations` / `gateway.labels`    | Extra `HTTPRoute` metadata (`labels` also go on the `ListenerSet`)                             | `{}`                                                      |
| `gateway.listenerSet.enabled`               | Creates a `ListenerSet` with this release's HTTPS listener; requires `gateway.enabled=true`    | `false`                                                   |
| `gateway.listenerSet.parentRef`             | The shared Gateway (`name`, `namespace`); required when enabled                                | `{}`                                                      |
| `gateway.listenerSet.listenerName` / `port` | Listener name (the route's `sectionName`) and port                                             | `https` / `443`                                           |
| `gateway.listenerSet.tlsSecretName`         | TLS Secret for the listener                                                                    | `<release fullname>-tls`                                  |
| `gateway.listenerSet.annotations`           | `ListenerSet` annotations (e.g. the cert-manager issuer)                                       | `{}`                                                      |
| `dashboard.enabled`                         | Enables the dashboard and allows configuration of credentials                                  | `false`                                                   |
| `dashboard.username`                        | Dashboard username                                                                             | `my-dashboard-username`                                   |
| `dashboard.password`                        | Dashboard password                                                                             | `my-dashboard-password`                                   |
| `av.enabled`                                | Enables audio/video support                                                                   | `false`                                                   |
| `av.serverIP`                               | IP address for A/V server                                                                      | `auto`                                                    |
| `av.stunServers.enabled`                    | Enables private STUN servers                                                                  | `false`                                                   |
| `av.stunServers.server`                     | STUN server address                                                                           | `coturn.example.com`                                      |
| `av.stunServers.secret`                     | STUN server secret                                                                            | `my-secret`                                               |
| `service.port`                              | Port for CodeTogether Collab service                                                         | `443`                                                     |
| `restart.enabled`                           | Enables periodic restarts for the server                                                     | `true`                                                    |
| `restart.cronPattern`                       | Cron pattern for scheduling restarts                                                         | `* 11 * * 0`                                              |
| `favicon.enabled`                           | Enables a custom favicon                                                                     | `false`                                                   |
| `favicon.filePath`                          | Path to the custom favicon                                                                   | `files/new-favicon.ico`                                   |

## Creating your Kubernetes Namespace for CodeTogether Collab

To create a namespace for CodeTogether Collab objects:

```bash
$ kubectl create namespace codetogether-collab
$ kubectl config set-context --current --namespace=codetogether-collab
```

## TLS

To secure CodeTogether, you can add a `secret` that contains your TLS (Transport Layer Security) private key and certificate:

```bash
$ kubectl create secret tls codetogether-tls --key <your-private-key-filename> --cert <your-certificate-filename>
```

## Gateway API (NGINX Gateway Fabric)

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

The chart renders an `HTTPRoute` for the `codetogether.url` host that sends `/`
to the chart Service. WebSocket connections need no extra setting: NGINX Gateway
Fabric passes the upgrade through. Settings you added as Ingress annotations
(`ingress.annotations`, `ingress.config`) don't carry over; set the equivalent on
your Gateway.

### ListenerSet: your own listener on a shared Gateway

Instead of adding a listener to the shared `Gateway` for this host, the chart
can create a `ListenerSet` (`gateway.networking.k8s.io/v1`, Gateway API v1.5+)
that adds the HTTPS listener for the `codetogether.url` host, with its
certificate, from the release namespace. The `HTTPRoute` then attaches to that
ListenerSet, so leave `gateway.parentRefs` empty:

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
    # The certificate Secret defaults to <release fullname>-tls. Set
    # tlsSecretName: codetogether-tls to keep the certificate from the TLS step.
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

Chart versions before 1.3.0 don't render Gateway API objects, so a Gateway setup
on them was applied by hand. If a ListenerSet or an HTTPRoute with the release
fullname already exists, Helm refuses to take it over (`invalid ownership
metadata`) and the upgrade stops without changing anything. Let Helm adopt each
one that exists before the upgrade:

```bash
for kind in listenerset httproute; do
  kubectl -n <namespace> label $kind <release-fullname> app.kubernetes.io/managed-by=Helm
  kubectl -n <namespace> annotate $kind <release-fullname> \
    meta.helm.sh/release-name=<release> meta.helm.sh/release-namespace=<namespace>
done
```

With the same host and TLS Secret name, the upgrade keeps serving traffic and
cert-manager keeps the existing certificate.

A `helm rollback` to a chart version without `gateway`, or a `helm uninstall`,
deletes the ListenerSet and the HTTPRoute, and with them this host's listener
and route.

The chart doesn't create the `Gateway`. On the Gateway side, check that:

- the listener allows routes from the release namespace
  (`allowedRoutes.namespaces`);
- the listener can read its certificate Secret. A Secret in another namespace
  needs a `ReferenceGrant` there;
- the route is accepted:
  `kubectl get httproute <release-fullname> -o jsonpath='{.status.parents[*].conditions}'`
  (the install notes print the exact command).

## Installing the Chart

To install the chart with the release name `codetogether-collab`:

```bash
$ helm install codetogether-collab -f codetogether-values.yaml ./codetogether-collab
```

You can verify the deployment using:

```bash
$ helm list
$ kubectl get all -n codetogether-collab
```

## Updating the Chart

To upgrade CodeTogether Collab to a newer version:

```bash
$ helm repo update
$ helm upgrade codetogether-collab -f codetogether-values.yaml ./codetogether-collab
```

## Uninstalling the Chart

To uninstall the `codetogether-collab` release:

```bash
$ helm uninstall codetogether-collab
