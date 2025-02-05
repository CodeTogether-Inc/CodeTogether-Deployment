# CodeTogether Helm Chart Repository

This repository contains Helm charts for deploying CodeTogether software, including:

Intelligence Suite – Engineering intelligence for data-driven insights
Collabolation Module – Real-time collaboration within the IDE

## Latest Helm Charts

### CodeTogether Intel

The `codetogether/codetogether-intel` Helm chart deploys the latest version of the CodeTogether Intelligence Suite backend. The Intelligence Suite leverages DevEx Workflow AI to drive goal-oriented success. It operates independently of server connectivity, allowing clients to continue tracking project activity locally and synchronize once the server is available.

### CodeTogether Collab

The `codetogether/codetogether-collab` Helm chart deploys the latest version of the CodeTogether Collabolation module backend. It enables real-time collaborative coding within the IDE, enhancing team synergy and communication across projects.

## Deprecated Helm Charts

### CodeTogether HQ

The `codetogether/codetogether-hq` Helm chart supports legacy users needing to deploy a previous version of the CodeTogether HQ Intelligence Suite backend.

### CodeTogether Live

The `codetogether/codetogether` Helm chart supports legacy users needing to deploy a previous version of the CodeTogether Live backend.

## Getting Started

Add the CodeTogether repository to your Helm configuration:
`helm repo add codetogether https://helm.codetogether.io`

Install a Helm chart using:
`helm install codetogether codetogether/codetogether -f codetogether-values.yaml`
