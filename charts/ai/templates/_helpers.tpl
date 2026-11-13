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
{{- $_ = include "ctai.validateWritableDirectories" . -}}
{{- end }}

{{/*
The first image version whose start-ctai runs on a read-only root filesystem.
Older images remove /opt/ctai/www (a mount point here) and write next to the
properties file, so they crash-loop under it.
*/}}
{{- define "ctai.readOnlyRootFilesystemMinImage" -}}
1.2.0-SET-AT-RELEASE
{{- end }}

{{/*
"true" when the container runs with a read-only root filesystem:
securityContext.readOnlyRootFilesystem is true and the image is not older than
ctai.readOnlyRootFilesystemMinImage. The image's version is image.tag, or the
chart's appVersion when the tag is empty; a tag that is not a version (latest) or
a digest is taken as supporting it. --reuse-values from a chart before 0.2.5 has
no readOnlyRootFilesystem, so it keeps the previous layout.
*/}}
{{- define "ctai.readOnlyRootFilesystem" -}}
{{- if and (eq (include "ctai.readOnlyRootFilesystemRequested" .) "true") (eq (include "ctai.imageTooOldForReadOnlyRoot" .) "false") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
"true" when securityContext.readOnlyRootFilesystem is true (validateWritableDirectories
refuses anything but a boolean).
*/}}
{{- define "ctai.readOnlyRootFilesystemRequested" -}}
{{- if eq ((.Values.securityContext | default dict).readOnlyRootFilesystem) true -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
"true" when the image is a version older than ctai.readOnlyRootFilesystemMinImage.
The version is the tag's leading x.y.z, so 1.2.8000-hotfix counts as 1.2.8000.
*/}}
{{- define "ctai.imageTooOldForReadOnlyRoot" -}}
{{- $image := .Values.image | default dict -}}
{{- $tag := toString ($image.tag | default .Chart.AppVersion) -}}
{{- $version := regexFind "^[0-9]+\\.[0-9]+\\.[0-9]+" (trimPrefix "v" $tag) -}}
{{- if and (not $image.digest) $version (semverCompare (printf "< %s" (include "ctai.readOnlyRootFilesystemMinImage" .)) $version) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
writableDirectories with the chart defaults underneath, as YAML: --reuse-values
from a chart before 0.2.5 has none.
*/}}
{{- define "ctai.writableDirectories" -}}
{{- $defaults := dict
  "runtime" (dict "enabled" true "mountPath" "/opt/ctai/runtime" "sizeLimit" "")
  "www" (dict "enabled" true "mountPath" "/opt/ctai/www" "sizeLimit" "")
  "logs" (dict "enabled" true "mountPath" "/opt/ctai/logs" "sizeLimit" "")
  "tmp" (dict "enabled" true "mountPath" "/opt/ctai/tmp" "sizeLimit" "")
  "systemTmp" (dict "enabled" true "mountPath" "/tmp" "sizeLimit" "") -}}
{{- toYaml (mergeOverwrite $defaults (deepCopy (.Values.writableDirectories | default dict))) -}}
{{- end }}

{{/*
writableDirectories: every enabled entry needs an absolute mountPath, no two
volumes may be mounted on the same path (Kubernetes rejects the pod, or compares
the paths as strings and lets one volume hide the other, and neither error names
the chart value nor the fix), and a disabled entry needs a volume of the
customer's in extraVolumeMounts, since the path is read-only otherwise. Paths are
compared after path.Clean, so /opt/ctai/logs/ is /opt/ctai/logs.
*/}}
{{- define "ctai.validateWritableDirectories" -}}
{{- $ro := (.Values.securityContext | default dict).readOnlyRootFilesystem -}}
{{- if and (not (kindIs "invalid" $ro)) (not (kindIs "bool" $ro)) -}}
{{- fail (printf "securityContext.readOnlyRootFilesystem must be true or false, got %q (a string): set it without quotes, or with --set rather than --set-string" (toString $ro)) -}}
{{- end -}}
{{- if eq (include "ctai.readOnlyRootFilesystem" .) "true" -}}
{{- $seen := dict -}}
{{- $extra := dict -}}
{{- range .Values.extraVolumeMounts -}}
{{- $_ := set $extra (clean (toString .mountPath)) true -}}
{{- end -}}
{{- $volumeNames := dict -}}
{{- range $name, $dir := (include "ctai.writableDirectories" . | fromYaml) -}}
{{- if not (kindIs "map" $dir) -}}
{{- fail (printf "writableDirectories.%s must be a map (enabled, mountPath, sizeLimit), got %v: to mount your own volume there, set writableDirectories.%s.enabled=false" $name $dir $name) -}}
{{- end -}}
{{- $volumeName := printf "writable-%s" ($name | kebabcase) -}}
{{- if hasKey $volumeNames $volumeName -}}
{{- fail (printf "writableDirectories.%s and writableDirectories.%s both make the volume name %s: rename one" (get $volumeNames $volumeName) $name $volumeName) -}}
{{- end -}}
{{- $_ := set $volumeNames $volumeName $name -}}
{{- $path := toString $dir.mountPath -}}
{{- if not (hasPrefix "/" $path) -}}
{{- fail (printf "writableDirectories.%s.mountPath must be an absolute path, got %q" $name $path) -}}
{{- end -}}
{{- $path = clean $path -}}
{{- if include "ctai.writableDirectoryEnabled" $dir -}}
{{- if hasKey $seen $path -}}
{{- fail (printf "writableDirectories.%s and writableDirectories.%s both mount %s" (get $seen $path) $name $path) -}}
{{- end -}}
{{- $_ := set $seen $path $name -}}
{{- else if not (hasKey $extra $path) -}}
{{- fail (printf "writableDirectories.%s is disabled but nothing is mounted on %s, which is read-only then: mount your own volume there with extraVolumes and extraVolumeMounts, or set securityContext.readOnlyRootFilesystem=false" $name $path) -}}
{{- end -}}
{{- end -}}
{{- range .Values.extraVolumeMounts -}}
{{- $path := clean (toString .mountPath) -}}
{{- if hasKey $seen $path -}}
{{- fail (printf "extraVolumeMounts mounts %s, which writableDirectories.%s already mounts: set writableDirectories.%s.enabled=false to use your own volume there" .mountPath (get $seen $path) (get $seen $path)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
"true" (or empty) for a writableDirectories entry: enabled, or no enabled key.
*/}}
{{- define "ctai.writableDirectoryEnabled" -}}
{{- if or (not (hasKey . "enabled")) (eq .enabled true) -}}
true
{{- end -}}
{{- end }}

{{/*
The container's securityContext, with readOnlyRootFilesystem as
ctai.readOnlyRootFilesystem resolves it.
*/}}
{{- define "ctai.containerSecurityContext" -}}
{{- $ctx := deepCopy (.Values.securityContext | default dict) -}}
{{- $_ := set $ctx "readOnlyRootFilesystem" (eq (include "ctai.readOnlyRootFilesystem" .) "true") -}}
{{- toYaml $ctx -}}
{{- end }}

{{/*
The container's volumeMounts: the properties file, the writableDirectories (only
with a read-only root filesystem), then extraVolumeMounts. Empty when there are none.
*/}}
{{- define "ctai.volumeMounts" -}}
{{- if eq (include "ctai.propertiesEnabled" .) "true" }}
- name: ctai-properties
  mountPath: {{ include "ctai.propertiesFilePath" . }}
  subPath: {{ .Values.properties.fileName }}
  readOnly: true
{{- end }}
{{- if eq (include "ctai.readOnlyRootFilesystem" .) "true" }}
{{- range $name, $dir := (include "ctai.writableDirectories" . | fromYaml) }}
{{- if include "ctai.writableDirectoryEnabled" $dir }}
- name: writable-{{ $name | kebabcase }}
  mountPath: {{ $dir.mountPath }}
{{- end }}
{{- end }}
{{- end }}
{{- with .Values.extraVolumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
The pod's volumes, matching ctai.volumeMounts. Empty when there are none.
*/}}
{{- define "ctai.volumes" -}}
{{- if eq (include "ctai.propertiesEnabled" .) "true" }}
- name: ctai-properties
  secret:
    secretName: {{ include "ctai.propertiesSecretName" . }}
{{- end }}
{{- if eq (include "ctai.readOnlyRootFilesystem" .) "true" }}
{{- range $name, $dir := (include "ctai.writableDirectories" . | fromYaml) }}
{{- if include "ctai.writableDirectoryEnabled" $dir }}
- name: writable-{{ $name | kebabcase }}
  emptyDir:
    {{- if $dir.sizeLimit }}
    sizeLimit: {{ $dir.sizeLimit }}
    {{- else }} {}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- with .Values.extraVolumes }}
{{ toYaml . }}
{{- end }}
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

{{/*
Proxies in front of the pod (Ingress controller or Gateway + in-pod nginx),
passed to the server as CTAI_INGEST_OTEL_TRUSTED_PROXY_HOPS.
*/}}
{{- define "ctai.trustedProxyHops" -}}
{{- $clientIp := .Values.clientIp | default dict -}}
{{- $hops := 2 -}}
{{- if hasKey $clientIp "trustedProxyHops" -}}
{{- $hops = $clientIp.trustedProxyHops -}}
{{- end -}}
{{- /* Validate the value as given: int would turn 2.9 into 2 and true into 1. */ -}}
{{- if or (kindIs "bool" $hops) (not (regexMatch "^[0-9]+$" (toString $hops))) -}}
{{- fail (printf "clientIp.trustedProxyHops must be a whole number of at least 1 (the in-pod nginx is always a hop), got %v" $hops) -}}
{{- end -}}
{{- $n := int $hops -}}
{{- if lt $n 1 -}}
{{- fail (printf "clientIp.trustedProxyHops must be a whole number of at least 1 (the in-pod nginx is always a hop), got %v" $hops) -}}
{{- end -}}
{{- $n -}}
{{- end }}

{{/*
Public host (with any port) from service_fqdn, as shown in the application URL.
*/}}
{{- define "ctai.publicHost" -}}
{{- (urlParse (include "ctai.serviceFqdn" .)).host -}}
{{- end }}

{{/*
HTTPRoute hostname: the public host without a port (Gateway API hostnames
can't carry one).
*/}}
{{- define "ctai.routeHostname" -}}
{{- regexReplaceAll ":[0-9]+$" (include "ctai.publicHost" .) "" -}}
{{- end }}

{{/*
"true" when extraEnvVars already sets CTAI_INGEST_OTEL_TRUSTED_PROXY_HOPS, so
the chart doesn't render a duplicate.
*/}}
{{- define "ctai.trustedProxyHopsInExtraEnv" -}}
{{- range .Values.extraEnvVars -}}
{{- if eq (toString .name) "CTAI_INGEST_OTEL_TRUSTED_PROXY_HOPS" -}}true{{- end -}}
{{- end -}}
{{- end }}

{{/*
Whether to render the NGINX Gateway Fabric ClientSettingsPolicy: "true" or "".
*/}}
{{- define "ctai.renderClientSettingsPolicy" -}}
{{- if (.Values.gateway | default dict).enabled -}}
{{- $mode := toString (((.Values.gateway | default dict).nginxGatewayFabric | default dict).clientSettingsPolicy | default dict).enabled -}}
{{- if eq $mode "true" -}}
true
{{- else if and (eq $mode "auto") (.Capabilities.APIVersions.Has "gateway.nginx.org/v1alpha1/ClientSettingsPolicy") -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
ClientSettingsPolicy body limit. Read defensively: a `helm upgrade --reuse-values`
from a chart without `gateway` keeps the old values and skips these defaults.
*/}}
{{- define "ctai.clientSettingsBodyMaxSize" -}}
{{- (((.Values.gateway | default dict).nginxGatewayFabric | default dict).clientSettingsPolicy | default dict).bodyMaxSize | default "16m" -}}
{{- end }}

{{/*
ListenerSet settings, read defensively like the rest of `gateway`.
*/}}
{{- define "ctai.listenerSetEnabled" -}}
{{- $gw := .Values.gateway | default dict -}}
{{- if and $gw.enabled ($gw.listenerSet | default dict).enabled -}}true{{- end -}}
{{- end }}

{{/*
HTTPRoute parentRefs: gateway.parentRefs when set; otherwise the chart's
ListenerSet and its listener.
*/}}
{{- define "ctai.routeParentRefs" -}}
{{- $gw := .Values.gateway | default dict -}}
{{- if $gw.parentRefs -}}
{{- toYaml $gw.parentRefs -}}
{{- else if eq (include "ctai.listenerSetEnabled" .) "true" -}}
- group: gateway.networking.k8s.io
  kind: ListenerSet
  name: {{ include "ctai.fullname" . }}
  sectionName: {{ ($gw.listenerSet | default dict).listenerName | default "https" }}
{{- end -}}
{{- end }}
