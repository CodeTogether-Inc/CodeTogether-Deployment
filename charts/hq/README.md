# README.md Helm Chart for CodeTogether HQ
# CodeTogether HQ Chart (Legacy)

> **⚠️ Legacy Chart**  
> This chart is now considered legacy and is not recommended for new deployments. Please use the `codetogether-intel` chart for configurations requiring `hqproperties.hq.collab.*`.


## Summary

This chart creates a CodeTogether HQ server deployment on a Kubernetes cluster using the Helm package manager.

## Prerequisites

This chart has been created with Helm v3 and tested with:

- Kubernetes v1.18+
- Helm v3.5+
- Cassandra v3.11+

## Configuration

The following table lists configurable parameters of the CodeTogether HQ chart and their default values:

| Parameter                                      | Description                                                                                   | Default                                                   |
|------------------------------------------------|-----------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `nameOverride`                                 | Overrides the name of the chart                                                              | `""`                                                     |
| `fullnameOverride`                             | Overrides the full name of the chart                                                         | `""`                                                     |
| `image.repository`                             | Docker image repository for CodeTogether HQ                                                  | `hub.edge.codetogether.com/releases/codetogether-hq`      |
| `image.pullPolicy`                             | Container image pull policy                                                                  | `Always`                                                  |
| `image.tag`                                    | Tag for the CodeTogether HQ image                                                            | `latest`                                                  |
| `imageCredentials.enabled`                     | Enables authentication for private Docker registry                                           | `true`                                                    |
| `imageCredentials.registry`                    | Docker registry URL                                                                          | `hub.edge.codetogether.com`                               |
| `imageCredentials.username`                    | Docker registry username                                                                     | `my-customer-username`                                    |
| `imageCredentials.password`                    | Docker registry password                                                                     | `my-customer-password`                                    |
| `imageCredentials.email`                       | Docker registry email                                                                        | `unused`                                                  |
| `codetogether.url`                             | Full URL for the CodeTogether HQ server                                                     | `https://<server-fqdn>`                                   |
| `hqproperties.hq.sso.client.id`                | Client ID for Single Sign-On (SSO)                                                          | `CLIENTID.apps.googleusercontent.com`                     |
| `hqproperties.hq.sso.client.secret`            | Client Secret for Single Sign-On (SSO)                                                      | `CLIENTSECRET`                                            |
| `hqproperties.hq.sso.client.issuer.url`        | Issuer URL for Single Sign-On (SSO)                                                         | `https://accounts.google.com`                             |
| `hqproperties.name.attr`                       | Name attribute for SSO                                                                       | `name`                                                    |
| `hqproperties.hq.db.type`                      | Database type for CodeTogether HQ                                                           | `CASSANDRA`                                               |
| `hqproperties.hq.secret`                       | Secret key for CodeTogether HQ                                                              | `SECRET1`                                                 |
| `hqproperties.hq.encryption.secret`            | Encryption secret key for CodeTogether HQ                                                   | `SECRET2`                                                 |
| `hqproperties.hq.base.url`                     | Base URL for CodeTogether HQ                                                                | `https://<server-fqdn>`                                   |
| `hqproperties.hq.cassandra.db.name`            | Cassandra database name                                                                     | `hq`                                                |
| `hqproperties.hq.cassandra.db.port`            | Cassandra database port                                                                     | `9042`                                                    |
| `hqproperties.hq.cassandra.db.host`            | Cassandra database host                                                                     | `codetogether-cassandra.default.svc.cluster.local`        |
| `hqproperties.hq.sso.redirect.uri`             | Redirect URI for SSO                                                                        | `https://<server-fqdn>/api/v1/auth/sso/success/hq`  |
| `hqproperties.hq.cassandra.db.password`        | Password for Cassandra database                                                             | `cassandra`                                               |
| `hqproperties.hq.cassandra.db.username`        | Username for Cassandra database                                                             | `cassandra`                                               |
| `hqproperties.hq.sso.role.mapping.claim`       | Specifies the claim in the SSO token containing user roles                                 | `roles`                                                   |
| `hqproperties.hq.sso.role.mappings`           | Defines the role mappings for CodeTogether HQ                                              | `cthq_user,project-manager[pm],system-admin[sa]`          |
| `ingress.enabled`                              | Enables ingress controller resource                                                         | `true`                                                    |
| `ingress.annotations`                          | Annotations for ingress                                                                      | `{}`                                                      |
| `ingress.tls.secretName`                       | TLS secret name for ingress                                                                 | `codetogether-hq-tls`                                     |
| `service.type`                                 | Kubernetes service type                                                                     | `ClusterIP`                                               |
| `service.port`                                 | Port for CodeTogether HQ service                                                            | `1080`                                                    |
| `serviceAccount.create`                        | Specifies whether a service account should be created                                       | `true`                                                    |
| `serviceAccount.name`                          | Name of the service account                                                                 | `codetogether-hq`                                         |
| `replicaCount`                                 | Number of replicas for CodeTogether HQ deployment                                           | `1`                                                       |
| `readinessProbe.initialDelaySeconds`           | Initial delay before readiness probe is initiated                                           | `60`                                                      |
| `readinessProbe.periodSeconds`                 | Period between readiness probes                                                             | `60`                                                      |
| `readinessProbe.timeoutSeconds`                | Timeout for readiness probes                                                                | `15`                                                      |
| `livenessProbe.initialDelaySeconds`            | Initial delay before liveness probe is initiated                                            | `60`                                                      |
| `livenessProbe.periodSeconds`                  | Period between liveness probes                                                              | `60`                                                      |
| `livenessProbe.timeoutSeconds`                 | Timeout for liveness probes                                                                 | `15`                                                      |

## Role Mappings Configuration

The following parameters are used to configure role mappings for the application:

- `hq.sso.role.mapping.claim`: Specifies the claim name in the SSO (Single Sign-On) token that contains the user's roles. In this case, it is set to `roles`.

- `hq.sso.role.mappings`: Defines the mappings for user roles in the system. The mappings are configured as follows:
  - `cthq_user`: Represents regular users with standard access to the system.
  - `project-manager[pm]`: Represents project managers, identified with the `[pm]` suffix, who have elevated permissions to manage project-specific operations.
  - `system-admin[sa]`: Represents system administrators, identified with the `[sa]` suffix, who have the highest level of access, including administrative privileges across the system.

These role mappings ensure that users are assigned appropriate permissions based on their roles, as provided by the SSO service. Proper configuration of these parameters is crucial for maintaining secure and role-based access control within the application.


## Creating your Kubernetes Namespace for CodeTogether HQ

It is a best practice to create a dedicated namespace for CodeTogether HQ objects. To create a namespace:

```bash
$ kubectl create namespace codetogether-hq
$ kubectl config set-context --current --namespace=codetogether-hq
```

## TLS

To secure CodeTogether, you can add a `secret` that contains your TLS (Transport Layer Security) private key and certificate:

```bash
$ kubectl create secret tls codetogether-hq-tls --key <your-private-key-filename> --cert <your-certificate-filename>
```

## Installing the Chart

To install the chart with the release name `codetogether-hq`:

```bash
$ helm install codetogether-hq -f codetogether-values.yaml ./codetogether-hq
```

You can verify the deployment using:

```bash
$ helm list
$ kubectl get all -n codetogether-hq
```

## Updating the Chart

To upgrade CodeTogether HQ to a newer version:

```bash
$ helm repo update
$ helm upgrade codetogether-hq -f codetogether-values.yaml ./codetogether-hq
```

## Uninstalling the Chart

To uninstall the `codetogether-hq` release:

```bash
$ helm uninstall codetogether-hq
