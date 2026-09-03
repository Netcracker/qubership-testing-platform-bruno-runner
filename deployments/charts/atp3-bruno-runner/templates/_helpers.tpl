{{/*
Return the fully qualified name.
*/}}
{{- define "atp3-bruno-runner.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the chart name.
*/}}
{{- define "atp3-bruno-runner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "atp3-bruno-runner.compatibility.isOpenshift" -}}
{{- .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}
{{- end -}}

{{- define "securityContext.pod" -}}
{{- $defaults := dict
  "runAsNonRoot" true
  "seccompProfile" (dict "type" "RuntimeDefault")
-}}
{{- $merged := mergeOverwrite (dict) $defaults (.Values.POD_SECURITY_CONTEXT | default dict) -}}
{{- if eq (include "atp3-bruno-runner.compatibility.isOpenshift" .) "true" }}
{{- $merged = omit $merged "runAsUser" "runAsGroup" "fsGroup" -}}
{{- end }}
{{- toYaml $merged -}}
{{- end -}}

{{- define "securityContext.container" -}}
{{- $defaults := dict
  "allowPrivilegeEscalation" false
  "capabilities" (dict "drop" (list "ALL"))
-}}
{{- toYaml (mergeOverwrite (dict) $defaults (.Values.CONTAINER_SECURITY_CONTEXT | default dict)) -}}
{{- end -}}