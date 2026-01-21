{{/*
Reusable livenessProbe template for validation service
*/}}
{{- define "validation.livenessProbe" -}}
livenessProbe:
  httpGet:
    path: {{ .Values.deployment.healthChecks.liveness.path }}
    port: {{ .Values.service.targetPort }}
  initialDelaySeconds: {{ .Values.deployment.healthChecks.liveness.initialDelaySeconds }}
  periodSeconds: {{ .Values.deployment.healthChecks.liveness.periodSeconds }}
  timeoutSeconds: {{ .Values.deployment.healthChecks.liveness.timeoutSeconds }}
  failureThreshold: {{ .Values.deployment.healthChecks.liveness.failureThreshold }}
{{- end -}}

{{/*
Reusable readinessProbe template for validation service
*/}}
{{- define "validation.readinessProbe" -}}
readinessProbe:
  httpGet:
    path: {{ .Values.deployment.healthChecks.readiness.path }}
    port: {{ .Values.service.targetPort }}
  initialDelaySeconds: {{ .Values.deployment.healthChecks.readiness.initialDelaySeconds }}
  periodSeconds: {{ .Values.deployment.healthChecks.readiness.periodSeconds }}
  timeoutSeconds: {{ .Values.deployment.healthChecks.readiness.timeoutSeconds }}
  failureThreshold: {{ .Values.deployment.healthChecks.readiness.failureThreshold }}
{{- end -}}

{{/*
Reusable startupProbe template for validation service
*/}}
{{- define "validation.startupProbe" -}}
startupProbe:
  httpGet:
    path: {{ .Values.deployment.healthChecks.startup.path }}
    port: {{ .Values.service.targetPort }}
  initialDelaySeconds: {{ .Values.deployment.healthChecks.startup.initialDelaySeconds }}
  periodSeconds: {{ .Values.deployment.healthChecks.startup.periodSeconds }}
  timeoutSeconds: {{ .Values.deployment.healthChecks.startup.timeoutSeconds }}
  failureThreshold: {{ .Values.deployment.healthChecks.startup.failureThreshold }}
{{- end -}}