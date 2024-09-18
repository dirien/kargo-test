{{- define "environmentSelector" -}}
  {{- if eq . "dev" }}development
  {{- else if eq . "uat" }}staging
  {{- else if eq . "prod" }}production
  {{- else }}unknown
  {{- end -}}
{{- end -}}
