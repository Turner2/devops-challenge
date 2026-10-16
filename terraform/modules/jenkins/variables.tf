variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the controller."
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to open the Jenkins UI on port 8080."
  type        = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "volume_size_gb" {
  type    = number
  default = 30
}

variable "git_repository_url" {
  description = "HTTPS URL of the repository the pipeline builds."
  type        = string
}

variable "git_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_url" {
  type = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "kubernetes_version" {
  description = "Used to install a matching kubectl."
  type        = string
}

variable "deploy_namespace" {
  description = "The only namespace Jenkins may deploy into."
  type        = string
}

variable "alarm_topic_arns" {
  type    = list(string)
  default = []
}

variable "wait_for" {
  description = "Any value from a resource Jenkins must start after (e.g. the load balancer controller release)."
  type        = any
  default     = null
}
