variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "pod_identity_trust_policy" {
  description = "Trust policy JSON for EKS Pod Identity (output of the eks module)."
  type        = string
}

variable "chart_version" {
  description = "Helm chart version. A matching policies/iam-policy-v<version>.json must exist in this module."
  type        = string
  default     = "3.6.0"
}
