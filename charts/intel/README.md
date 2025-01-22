# README.md Helm Chart for CodeTogether Intel



## Summary

This chart creates a CodeTogether Intel server deployment on a Kubernetes cluster using the Helm package manager.

## Prerequisites

This chart has been created with Helm v3 and tested with:

- Kubernetes v1.18+
- Helm v3.5+
- Cassandra v3.11+

## Configuration

The following table lists configurable parameters of the CodeTogether Intel chart and their default values:

| Parameter                                      | Description                                                                                   | Default                                                   |
|------------------------------------------------|-----------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `nameOverride`                                 | Overrides the name of the chart                                                              | `""`                                                     |
| `fullnameOverride`                             | Overrides the full name of the chart                                                         | `""`                                                     |
| `image.repository`                             | Docker image repository for CodeTogether Intel                                                  | `hub.edge.codetogether.com/releases/codetogether-intel`      |
| `image.pullPolicy`                             | Container image pull policy                                                                  | `Always`                                                  |
| `image.tag`                                    | Tag for the CodeTogether Intel image                                                            | `latest`                                                  |
| `imageCredentials.enabled`                     | Enables authentication for private Docker registry                                           | `true`                                                    |
| `imageCredentials.registry`                    | Docker registry URL                                                                          | `hub.edge.codetogether.com`                               |
| `imageCredentials.username`                    | Docker registry username                                                                     | `my-customer-username`                                    |
| `imageCredentials.password`                    | Docker registry password                                                                     | `my-customer-password`                                    |
| `imageCredentials.email`                       | Docker registry email                                                                        | `unused`                                                  |
| `codetogether.url`                             | Full URL for the CodeTogether Intel server                                                     | `https://<server-fqdn>`                                   |
| `hqproperties.hq.sso.client.id`                | Client ID for Single Sign-On (SSO)                                                          | `CLIENTID.apps.googleusercontent.com`                     |
| `hqproperties.hq.sso.client.secret`            | Client Secret for Single Sign-On (SSO)                                                      | `CLIENTSECRET`                                            |
| `hqproperties.hq.sso.client.issuer.url`        | Issuer URL for Single Sign-On (SSO)                                                         | `https://accounts.google.com`                             |
| `hqproperties.name.attr`                       | Name attribute for SSO                                                                       | `name`                                                    |
| `hqproperties.hq.db.type`                      | Database type for CodeTogether Intel                                                           | `CASSANDRA`                                               |
| `hqproperties.hq.secret`                       | Secret key for CodeTogether Intel                                                              | `SECRET1`                                                 |
| `hqproperties.hq.encryption.secret`            | Encryption secret key for CodeTogether Intel                                                   | `SECRET2`                                                 |
| `hqproperties.hq.base.url`                     | Base URL for CodeTogether Intel                                                                | `https://<server-fqdn>`                                   |
| `hqproperties.hq.cassandra.db.name`            | Cassandra database name                                                                     | `intel`                                                |
| `hqproperties.hq.cassandra.db.port`            | Cassandra database port                                                                     | `9042`                                                    |
| `hqproperties.hq.cassandra.db.host`            | Cassandra database host                                                                     | `codetogether-cassandra.default.svc.cluster.local`        |
| `hqproperties.hq.sso.redirect.uri`             | Redirect URI for SSO                                                                        | `https://<server-fqdn>/api/v1/auth/sso/success/intel`  |
| `hqproperties.hq.cassandra.db.password`        | Password for Cassandra database                                                             | `cassandra`                                               |
| `hqproperties.hq.cassandra.db.username`        | Username for Cassandra database                                                             | `cassandra`                                               |
| `hqproperties.hq.collab.url`               | URL of the collaboration server integrated with Intel                                              | `https://your-collab-server`                               |
| `hqproperties.hq.collab.secret`            | Secret key for secure communication with the collaboration server                               | `SECRET`                                                  |

| `ingress.enabled`                              | Enables ingress controller resource                                                         | `true`                                                    |
| `ingress.annotations`                          | Annotations for ingress                                                                      | `{}`                                                      |
| `ingress.tls.secretName`                       | TLS secret name for ingress                                                                 | `codetogether-intel-tls`                                     |
| `service.type`                                 | Kubernetes service type                                                                     | `ClusterIP`                                               |
| `service.port`                                 | Port for CodeTogether Intel service                                                            | `1080`                                                    |
| `serviceAccount.create`                        | Specifies whether a service account should be created                                       | `true`                                                    |
| `serviceAccount.name`                          | Name of the service account                                                                 | `codetogether-intel`                                         |
| `replicaCount`                                 | Number of replicas for CodeTogether Intel deployment                                           | `1`                                                       |
| `readinessProbe.initialDelaySeconds`           | Initial delay before readiness probe is initiated                                           | `60`                                                      |
| `readinessProbe.periodSeconds`                 | Period between readiness probes                                                             | `60`                                                      |
| `readinessProbe.timeoutSeconds`                | Timeout for readiness probes                                                                | `15`                                                      |
| `livenessProbe.initialDelaySeconds`            | Initial delay before liveness probe is initiated                                            | `60`                                                      |
| `livenessProbe.periodSeconds`                  | Period between liveness probes                                                              | `60`                                                      |
| `livenessProbe.timeoutSeconds`                 | Timeout for liveness probes                                                                 | `15`                                                      |

## Creating your Kubernetes Namespace for CodeTogether Intel

It is a best practice to create a dedicated namespace for CodeTogether Intel objects. To create a namespace:

```bash
$ kubectl create namespace codetogether-intel
$ kubectl config set-context --current --namespace=codetogether-intel
```

## TLS

To secure CodeTogether, you can add a `secret` that contains your TLS (Transport Layer Security) private key and certificate:

```bash
$ kubectl create secret tls codetogether-intel-tls --key <your-private-key-filename> --cert <your-certificate-filename>
```

## Installing the Chart

To install the chart with the release name `codetogether-intel`:

```bash
$ helm install codetogether-intel -f codetogether-values.yaml ./codetogether-intel
```

You can verify the deployment using:

```bash
$ helm list
$ kubectl get all -n codetogether-intel
```

## Updating the Chart

To upgrade CodeTogether Intel to a newer version:

```bash
$ helm repo update
$ helm upgrade codetogether-intel -f codetogether-values.yaml ./codetogether-intel
```

## Uninstalling the Chart

To uninstall the `codetogether-intel` release:

```bash
$ helm uninstall codetogether-intel
