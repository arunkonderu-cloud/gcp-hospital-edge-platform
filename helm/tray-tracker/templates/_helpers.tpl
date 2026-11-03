{{- define "tray-tracker.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "tray-tracker.labels" -}}
app.kubernetes.io/name: {{ include "tray-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
site: {{ .Values.siteId | quote }}
{{- end -}}

{{- define "tray-tracker.selector" -}}
app.kubernetes.io/name: {{ include "tray-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "tray-tracker.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}
