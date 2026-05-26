{{- define "app-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-platform.fullname" -}}
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

{{- define "app-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "app-platform.labels" -}}
helm.sh/chart: {{ include "app-platform.chart" . }}
app.kubernetes.io/name: {{ include "app-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "app-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "app-platform.databaseUrl" -}}
{{- if .Values.externalDatabase.databaseUrl -}}
{{- .Values.externalDatabase.databaseUrl -}}
{{- else -}}
{{- printf "postgresql://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "app-platform.fullname" .) .Values.postgresql.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "app-platform.redisUrl" -}}
{{- if .Values.externalRedis.redisUrl -}}
{{- .Values.externalRedis.redisUrl -}}
{{- else -}}
{{- printf "redis://%s-redis:6379/0" (include "app-platform.fullname" .) -}}
{{- end -}}
{{- end -}}

