variable "project_name" {
  type    = string
  default = "devops-challenge"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# --- Network ---------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (2 or 3)."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheaper) instead of one per AZ (highly available egress)."
  type        = bool
  default     = false
}

# --- EKS -------------------------------------------------------------------
variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
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
  description = "Extra IAM principals that get kubectl cluster-admin."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  type    = number
  default = 14
}

# --- Application -----------------------------------------------------------
variable "app_name" {
  type    = string
  default = "product-catalog"
}

variable "app_namespace" {
  type    = string
  default = "product-catalog"
}

variable "alb_name" {
  description = "Must match the load-balancer-name annotation in k8s/ingress.yaml."
  type        = string
  default     = "product-catalog-prod"
}

variable "alarm_email" {
  type    = string
  default = ""
}

# --- CI/CD -----------------------------------------------------------------
variable "git_repository_url" {
  type    = string
  default = "https://github.com/Turner2/devops-challenge.git"
}

variable "git_branch" {
  type    = string
  default = "main"
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "jenkins_allowed_cidrs" {
  description = "Who can open the Jenkins UI. Narrow this to your own IP outside of a review period."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
