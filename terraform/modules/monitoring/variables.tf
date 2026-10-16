variable "name" {
  description = "Name prefix for alarms, topic and dashboard."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  description = "Kubernetes namespace of the app."
  type        = string
}

variable "app_name" {
  description = "Deployment name (Container Insights reports pods under this PodName)."
  type        = string
}

variable "service_name" {
  description = "Kubernetes Service name."
  type        = string
}

variable "alb_name" {
  description = "ALB name set in the Ingress annotation, used to find its metrics."
  type        = string
}

variable "min_running_pods" {
  type    = number
  default = 2
}

variable "alarm_email" {
  description = "Optional e-mail for alarm notifications (AWS sends a confirmation link)."
  type        = string
  default     = ""
}
