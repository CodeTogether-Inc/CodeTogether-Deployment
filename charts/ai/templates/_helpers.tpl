{{/*
Expand the name of the chart.
*/}}
{{- define "ctai.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ctai.fullname" -}}
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
Chart label
*/}}
{{- define "ctai.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ctai.labels" -}}
helm.sh/chart: {{ include "ctai.chart" . }}
{{ include "ctai.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ctai.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ctai.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "ctai.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ctai.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Docker registry pull secret payload
*/}}
{{- define "ctai.imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
True when the chart should render a properties Secret (not external ref).
*/}}
{{- define "ctai.propertiesFromChart" -}}
{{- if .Values.ctaipropertiessecret.enabled -}}
false
{{- else if .Values.ctaiPropertiesFile -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
True when the deployment should mount properties from a Secret.
*/}}
{{- define "ctai.propertiesEnabled" -}}
{{- if .Values.ctaipropertiessecret.enabled -}}
true
{{- else if .Values.ctaiPropertiesFile -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Secret that holds ctai-configuration.properties
*/}}
{{- define "ctai.propertiesSecretName" -}}
{{- if .Values.ctaipropertiessecret.enabled -}}
{{- .Values.ctaipropertiessecret.ref -}}
{{- else -}}
{{- printf "%s-properties" (include "ctai.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Full path passed to CTAI_PROPERTIES_FILE
*/}}
{{- define "ctai.propertiesFilePath" -}}
{{- printf "%s/%s" .Values.properties.mountPath .Values.properties.fileName -}}
{{- end }}

{{/*
True when deployment should inject CTAI_PROTECTED_STORAGE_MASTER_KEY_B64 from a Secret.
*/}}
{{- define "ctai.masterKeyEnvEnabled" -}}
{{- if eq .Values.masterKey.source "secret" -}}
{{- if .Values.masterKey.existingSecret -}}true{{- else -}}false{{- end -}}
{{- else if eq .Values.masterKey.source "auto" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
True when the chart should render secret-master-key.yaml (auto-generate only).
*/}}
{{- define "ctai.masterKeyRenderSecret" -}}
{{- if eq .Values.masterKey.source "auto" -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
Secret that holds the protected-storage master key.
*/}}
{{- define "ctai.masterKeySecretName" -}}
{{- if eq .Values.masterKey.source "secret" -}}
{{- .Values.masterKey.existingSecret -}}
{{- else -}}
{{- printf "%s-master-key" (include "ctai.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Raw properties text available to Helm at template time (--set-file only).
Not available when ctaipropertiessecret points at a pre-created Secret.
*/}}
{{- define "ctai.rawPropertiesContent" -}}
{{- if .Values.ctaiPropertiesFile -}}
{{- .Values.ctaiPropertiesFile -}}
{{- end -}}
{{- end }}

{{/*
Parse service_fqdn= from properties file text.
*/}}
{{- define "ctai.serviceFqdnFromContent" -}}
{{- $line := regexFind "(?m)^service_fqdn=[^\\r\\n#]+" (.content | default "") -}}
{{- if not $line -}}
{{- "" -}}
{{- else -}}
{{- trimPrefix "service_fqdn=" $line | trim -}}
{{- end -}}
{{- end }}

{{/*
service_fqdn from properties file (empty when unavailable).
*/}}
{{- define "ctai.serviceFqdnFromProperties" -}}
{{- $content := include "ctai.rawPropertiesContent" . -}}
{{- if $content -}}
{{- include "ctai.serviceFqdnFromContent" (dict "content" $content) -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end }}

{{/*
Public service URL for Ingress and env-only installs.
Prefers explicit service.fqdn; otherwise service_fqdn from properties.
Fails when missing, mismatched, or invalid.
*/}}
{{- define "ctai.serviceFqdn" -}}
{{- $explicit := .Values.service.fqdn | default "" | trim -}}
{{- $derived := include "ctai.serviceFqdnFromProperties" . | trim -}}
{{- if and $explicit $derived (ne $explicit $derived) -}}
{{- fail (printf "service.fqdn (%s) does not match service_fqdn in properties (%s)" $explicit $derived) -}}
{{- end -}}
{{- $url := "" -}}
{{- if $explicit -}}
{{- $url = $explicit -}}
{{- else if $derived -}}
{{- $url = $derived -}}
{{- else if .Values.ctaipropertiessecret.enabled -}}
{{- fail "ctaipropertiessecret is enabled but service.fqdn is not set. Helm cannot read service_fqdn from a pre-created Secret at template time — set service.fqdn to the same value as service_fqdn in that Secret." -}}
{{- else -}}
{{- fail "Public URL is required: set service_fqdn in ctai-configuration.properties (--set-file) or set service.fqdn for env-only installs." -}}
{{- end -}}
{{- $parsed := urlParse $url -}}
{{- if not $parsed.host -}}
{{- fail (printf "service URL %q is not a valid URL with a host (from service.fqdn or service_fqdn in properties)" $url) -}}
{{- end -}}
{{- $url -}}
{{- end }}

{{/*
Fail helm template when properties contain unfilled <placeholder> values or URL is invalid.
*/}}
{{- define "ctai.validateConfiguration" -}}
{{- $content := include "ctai.rawPropertiesContent" . -}}
{{- if $content -}}
{{- if regexMatch "(?m)^[^#\\n].*<[^>]+>" $content -}}
{{- fail "ctai-configuration.properties contains unfilled placeholders (non-comment lines with <...>). Copy ctai-configuration.properties.template, replace every placeholder, and try again." -}}
{{- end -}}
{{- end -}}
{{- $_ := include "ctai.serviceFqdn" . -}}
{{- end }}

{{/*
Host:port for CTAI_SERVICE_EXTERNAL_IDENTIFIER from the resolved service URL.
*/}}
{{- define "ctai.externalIdentifier" -}}
{{- $parsed := urlParse (include "ctai.serviceFqdn" .) -}}
{{- if $parsed.port -}}
{{- printf "%s:%s" $parsed.host ($parsed.port | toString) -}}
{{- else -}}
{{- $parsed.host -}}
{{- end -}}
{{- end }}
