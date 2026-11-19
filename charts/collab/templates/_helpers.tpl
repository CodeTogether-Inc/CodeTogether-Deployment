{{/*
Expand the name of the chart.
*/}}
{{- define "codetogether.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codetogether.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "codetogether.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "codetogether.labels" -}}
helm.sh/chart: {{ include "codetogether.chart" . }}
{{ include "codetogether.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "codetogether.selectorLabels" -}}
app.kubernetes.io/name: {{ include "codetogether.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "codetogether.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "codetogether.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Creating Image Pull Secrets
https://helm.sh/docs/howto/charts_tips_and_tricks/#creating-image-pull-secrets
*/}}
{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
Get Dashboard secret name
*/}}
{{- define "codetogether.dashboardSecretName" }}
{{- if .Values.dashboard.existingSecret }}
    {{- printf "%s" .Values.dashboard.existingSecret }}
{{- else }}
    {{- printf "%s-dashboard"  (include "codetogether.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Get Proxy secret name
*/}}
{{- define "codetogether.proxy.secretName" }}
{{- if .Values.proxy.existingSecret }}
  {{- .Values.proxy.existingSecret }}
{{- else }}
  {{- $fullName := include "codetogether.fullname" . -}}
  {{- with .Values.proxy }}
    {{- printf "%s-proxy-secret" $fullName }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Gateway API hostname: the codetogether.url host without a port (Gateway API
hostnames can't carry one).
*/}}
{{- define "codetogether.routeHostname" -}}
{{- $host := regexReplaceAll ":[0-9]+$" (urlParse (toString .Values.codetogether.url)).host "" -}}
{{- if not $host -}}
{{- fail "gateway.enabled=true requires codetogether.url to be a full URL with a host, for example https://codetogether.example.com." -}}
{{- end -}}
{{- $host -}}
{{- end }}

{{/*
"true" when the chart renders a ListenerSet. Read `gateway` defensively: a
`helm upgrade --reuse-values` from a chart without it keeps the old values and
skips the new defaults.
*/}}
{{- define "codetogether.listenerSetEnabled" -}}
{{- $gw := .Values.gateway | default dict -}}
{{- if and $gw.enabled ($gw.listenerSet | default dict).enabled -}}true{{- end -}}
{{- end }}

{{/*
HTTPRoute parentRefs: gateway.parentRefs when set; otherwise the chart's
ListenerSet and its listener.
*/}}
{{- define "codetogether.routeParentRefs" -}}
{{- $gw := .Values.gateway | default dict -}}
{{- if $gw.parentRefs -}}
{{- toYaml $gw.parentRefs -}}
{{- else if eq (include "codetogether.listenerSetEnabled" .) "true" -}}
- group: gateway.networking.k8s.io
  kind: ListenerSet
  name: {{ include "codetogether.fullname" . }}
  sectionName: {{ ($gw.listenerSet | default dict).listenerName | default "https" }}
{{- end -}}
{{- end }}
