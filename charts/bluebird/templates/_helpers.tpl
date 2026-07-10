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
Container image reference. Tag defaults to "latest".
*/}}
{{- define "bluebird.image" -}}
{{- $tag := default "latest" .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.name $tag -}}
{{- end -}}

{{/*
True when the workload should be an Argo Rollout (Canary/BlueGreen) rather than
a plain Deployment (RollingUpdate/Recreate).
*/}}
{{- define "bluebird.isRollout" -}}
{{- or (eq .Values.strategy "Canary") (eq .Values.strategy "BlueGreen") -}}
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
Pod template shared by Deployment and Rollout. Rendered to YAML and parsed
back into the spec dict so specOverrides can deep-merge into it.
*/}}
{{- define "bluebird.podTemplate" -}}
metadata:
  labels:
    {{- include "bluebird.selectorLabels" . | nindent 4 }}
    {{- with .Values.podLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: bluebird
      image: {{ include "bluebird.image" . | quote }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      ports:
        - name: http
          containerPort: {{ .Values.containerPort }}
          protocol: TCP
      {{- with .Values.extraEnv }}
      env:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      livenessProbe:
        {{- toYaml .Values.probes.liveness | nindent 8 }}
      readinessProbe:
        {{- toYaml .Values.probes.readiness | nindent 8 }}
      {{- if .Values.probes.startup.enabled }}
      startupProbe:
        {{- toYaml (omit .Values.probes.startup "enabled") | nindent 8 }}
      {{- end }}
      {{- with .Values.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
