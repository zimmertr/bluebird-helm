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
The deployment strategy. Supplying a `canary` or `blueGreen` block is taken as
choosing that strategy, since there is no reason to configure one you are not
using. An explicit `strategy` still wins, which is what keeps charts written
against 0.4.x rendering identically.
*/}}
{{- define "bluebird.strategy" -}}
{{- if .Values.strategy -}}
{{- .Values.strategy -}}
{{- else if .Values.canary -}}
{{- print "Canary" -}}
{{- else if .Values.blueGreen -}}
{{- print "BlueGreen" -}}
{{- else -}}
{{- print "RollingUpdate" -}}
{{- end -}}
{{- end -}}

{{/*
True when the workload should be an Argo Rollout (Canary/BlueGreen) rather than
a plain Deployment (RollingUpdate/Recreate).
*/}}
{{- define "bluebird.isRollout" -}}
{{- $strategy := include "bluebird.strategy" . -}}
{{- or (eq $strategy "Canary") (eq $strategy "BlueGreen") -}}
{{- end -}}

{{/*
Name of the Rollout's second Service (canaryService / previewService). The
strategy blocks are verbatim values, so honor an override there; everything
that must agree on this name (Service, VirtualService destination) derives it
from here.
*/}}
{{- define "bluebird.secondaryServiceName" -}}
{{- $default := printf "%s-canary" (include "bluebird.fullname" .) -}}
{{- if eq (include "bluebird.strategy" .) "BlueGreen" -}}
{{- tpl (default $default (.Values.blueGreen | default dict).previewService) . -}}
{{- else -}}
{{- tpl (default $default (.Values.canary | default dict).canaryService) . -}}
{{- end -}}
{{- end -}}

{{/*
The strategy block, with the chart's defaults filled in under whatever the user
supplied. Kept here rather than in values.yaml because a populated default there
would make "did you configure a canary?" always true and defeat the inference
above.
*/}}
{{- define "bluebird.strategySpec" -}}
{{- $name := include "bluebird.fullname" . -}}
{{- if eq (include "bluebird.strategy" .) "BlueGreen" -}}
{{- $defaults := dict "activeService" $name "previewService" (printf "%s-canary" $name) -}}
{{- toYaml (merge (deepCopy (.Values.blueGreen | default dict)) $defaults) -}}
{{- else -}}
{{- $defaults := dict "stableService" $name "canaryService" (printf "%s-canary" $name)
      "stableMetadata" (dict "labels" (dict "role" "stable"))
      "canaryMetadata" (dict "labels" (dict "role" "canary")) -}}
{{- toYaml (merge (deepCopy (.Values.canary | default dict)) $defaults) -}}
{{- end -}}
{{- end -}}
