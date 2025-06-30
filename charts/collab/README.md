# README.md Helm Chart for CodeTogether Collab

## Summary

This chart creates a CodeTogether Collab server deployment on a Kubernetes cluster using the Helm package manager.

## Prerequisites

This chart has been created with Helm v3 and tested with:

- Kubernetes v1.18+
- Helm v3.5+

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
