This is a Helm Chart repository for CodeTogether's Live, HQ, Collab, and Intel products.

## Helm Charts Directory

### CodeTogether Live

The `codetogether/codetogether` Helm chart can be used to deploy the CodeTogether Live
backend. Live provides teams the ability to code together real-time right from within 
their IDE.

### CodeTogether HQ

The `codetogether/codetogether-hq` Helm chart can be used to deploy the CodeTogether HQ
backend. HQ provides teams unique insights into project hotspots and areas of opportunity
to foster collaboration and on-time delivery of software.

### CodeTogether Collab

The `codetogether/codetogether-collab` Helm chart can be used to deploy CodeTogether Collab, a collaboration-focused service that helps teams work together efficiently, improving team synergy and communication across projects.

### CodeTogether Intel

The `codetogether/codetogether-intel` Helm chart can be used to deploy CodeTogether Intel. CodeTogether Intel is built to function even without connectivity to the server. During upgrade flows, CodeTogether Intel clients continue to track project activity locally and synchronize the appropriate activity when the server is available.

## Getting Started

To begin using the repository, first add it to your Helm configuration:
`helm repo add codetogether https://helm.codetogether.io`

Then you can provision services using a command such as:
`helm install codetogether codetogether/codetogether -f codetogether-values.yaml`