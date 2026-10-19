{{/*
Chart name (app.kubernetes.io/name). Constant across instances so a single
Service must ALSO match on the instance label to stay isolated.
*/}}
{{- define "bluebird.name" -}}
{{- default "bluebird" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Resource name base. Defaults to the release name (bluebird / bluebird-pr-<n>)
rather than the Helm "<release>-<chart>" convention, so names stay clean.
*/}}
{{- define "bluebird.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Target namespace — the release namespace (set by kustomize/Argo, not the chart).
*/}}
{{- define "bluebird.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{/*
Chart label value, e.g. bluebird-helm-0.1.0
*/}}
{{- define "bluebird.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels — the isolation boundary. Every Service, the Rollout pod
selector, and traffic routing key on BOTH of these. The instance label makes
stable and each preview mutually exclusive within a shared namespace.
*/}}
{{- define "bluebird.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bluebird.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common labels applied to all resources.
*/}}
{{- define "bluebird.labels" -}}
helm.sh/chart: {{ include "bluebird.chart" . }}
{{ include "bluebird.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: bluebird
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Container image reference. Tag defaults to the chart appVersion — a published
release tag. zimmertr/bluebird never publishes `latest`, so defaulting to it
breaks pulls and Artifact Hub's security scanning.
*/}}
{{- define "bluebird.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.name $tag -}}
{{- end -}}

{{/*
Name of the Rollout's second Service (canaryService / previewService). The
strategy blocks are verbatim values, so honor an override there; everything
that must agree on this name (Service, VirtualService destination) derives it
from here.
*/}}
{{- define "bluebird.secondaryServiceName" -}}
{{- $default := printf "%s-canary" (include "bluebird.fullname" .) -}}
{{- if eq .Values.strategy "BlueGreen" -}}
{{- tpl (default $default .Values.blueGreen.previewService) . -}}
{{- else -}}
{{- tpl (default $default .Values.canary.canaryService) . -}}
{{- end -}}
{{- end -}}

{{/*
The CloudNativePG cluster's name, as its own chart computes it for the
`database` alias, so the app can name the Secret and Service it creates.
*/}}
{{- define "bluebird.databaseName" -}}
{{- if .Values.database.fullnameOverride -}}
{{- .Values.database.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "database" .Values.database.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The app's database settings (bluebird#760), first-class rather than extraEnv
so a values file that replaces the extraEnv list cannot drop them. The
connection string comes from the Secret CloudNativePG writes for the
cluster's owner, or from `existingSecret` for a release reading another's.
*/}}
{{- define "bluebird.databaseEnv" -}}
{{- if .Values.database.enabled }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "bluebird.databaseName" . }}-app
      key: uri
{{- else if .Values.database.existingSecret }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.existingSecret }}
      key: uri
{{- end }}
{{- if .Values.database.readOnly }}
- name: DATABASE_READ_ONLY
  value: "true"
{{- end }}
{{- end -}}

{{/*
The fill image. Tag defaults to the chart appVersion, the release the app and
the fill share.
*/}}
{{- define "bluebird.fillImage" -}}
{{- $tag := default .Chart.AppVersion .Values.fill.image.tag -}}
{{- printf "%s:%s" .Values.fill.image.name $tag -}}
{{- end -}}
