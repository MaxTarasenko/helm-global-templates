{{/*
Expand the name of the chart.
*/}}
{{- define "global-one.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "global-one.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "global-one.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create url to service
*/}}
{{- define "service.url" -}}
{{- $namespace := "default" }}
{{- if .Release }}
  {{- if .Release.Namespace }}
    {{- $namespace = .Release.Namespace }}
  {{- end }}
{{- end }}
{{- printf "http://%s.%s.svc.cluster.local.:%s" .name $namespace .port  }}
{{- end -}}


{{/*
Common labels
*/}}
{{- define "global-one.labels" -}}
helm.sh/chart: {{ include "global-one.chart" . }}
{{ include "global-one.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "global-one.selectorLabels" -}}
app.kubernetes.io/name: {{ include "global-one.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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
