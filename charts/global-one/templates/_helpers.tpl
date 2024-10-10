{{/*
Expand the name of the chart.
*/}}
{{- define "global-one.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

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
  value: {{ printf "http://%s.%s.svc.cluster.local.:%s" $value.service_url.name (default "default" $global.Release.Namespace) (toString $value.service_url.port) | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "global-one.labels" -}}
helm.sh/chart: {{ include "global-one.chart" . }}
{{ include "global-one.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "global-one.selectorLabels" -}}
app.kubernetes.io/name: {{ include "global-one.fullname" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "global-one.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "global-one.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
