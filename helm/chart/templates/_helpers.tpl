{{- define "sms-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sms-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "sms-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sms-app.labels" -}}
helm.sh/chart: {{ include "sms-app.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "sms-app.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "sms-app.app.name" -}}
{{- printf "%s-app" (include "sms-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sms-app.model.name" -}}
{{- printf "%s-model" (include "sms-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sms-app.componentLabels" -}}
{{ include "sms-app.labels" .context }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
