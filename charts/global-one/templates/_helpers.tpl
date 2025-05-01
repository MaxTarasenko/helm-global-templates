{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "global-one.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "global-one.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
image block
*/}}
{{- define "global-one.image" -}}
{{- if .Values.image.env }}
{{- printf "%s/%s/%s:%s" .Values.image.repository .Values.image.env .Values.image.name .Values.image.tag | quote }}
{{- else if .Values.image.repository }}
{{- printf "%s/%s:%s" .Values.image.repository .Values.image.name .Values.image.tag | quote }}
{{- else }}
{{- printf "%s:%s" .Values.image.name .Values.image.tag | quote }}
{{- end }}
{{- end -}}

{{/*
 env block
*/}}
{{- define "global-one.env" -}}
{{- $global := . -}}
{{- range $name, $value := .Values.env }}
- name: {{ $name }}
  {{- if (typeOf $value) | eq "string" }}
  value: {{ $value | quote }}
  {{- else if $value.secret }}
  valueFrom:
    secretKeyRef:
      name: {{ $value.secret.name | quote }}
      key: {{ $value.secret.key | quote }}
  {{- else if $value.service_url }}
  value: {{ printf "http://%s.%s.svc.%s:%s%s" $value.service_url.name (default "default" $global.Release.Namespace) (default "cluster.local" $value.service_url.cluster) (toString $value.service_url.port) (default "" $value.service_url.path) | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "global-one.labels" -}}
helm.sh/chart: {{ include "global-one.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: {{ include "global-one.fullname" . }}
app.kubernetes.io/instance: {{ include "global-one.fullname" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "global-one.selectorLabels" -}}
app.kubernetes.io/name: {{ include "global-one.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Probe configuration
*/}}
{{- define "global-one.probe" -}}
{{- $probe := .probe -}}
{{- $healthCheck := .healthCheck -}}
{{- $name := .name -}}
{{- $port := .port -}}
{{ .type }}Probe:
  initialDelaySeconds: {{ and $probe $probe.initialDelaySeconds | default $healthCheck.initialDelaySeconds | default 2 }}
  periodSeconds: {{ and $probe $probe.periodSeconds | default $healthCheck.periodSeconds | default 10 }}
  timeoutSeconds: {{ and $probe $probe.timeoutSeconds | default $healthCheck.timeoutSeconds | default 2 }}
  failureThreshold: {{ and $probe $probe.failureThreshold | default $healthCheck.failureThreshold | default 5 }}
{{- if $healthCheck.useTCPSocket }}
  tcpSocket:
    port: {{ $port }}
{{- else }}
  httpGet:
    path: {{ and $probe $probe.path | default $healthCheck.path | default "/" }}
    port: {{ $name }}
{{- end }}
{{- end -}}
