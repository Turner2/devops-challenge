variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Keep it on a version in standard support."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets for the control plane ENIs and the worker nodes."
  type        = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "Who may reach the public Kubernetes API endpoint. In-VPC traffic (Jenkins) uses the private endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "control_plane_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_disk_size_gb" {
  type    = number
  default = 30
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "cluster_admin_arns" {
  description = "IAM users/roles that get cluster-admin through EKS access entries (the identity running Terraform gets it automatically)."
  type        = list(string)
  default     = []
}
