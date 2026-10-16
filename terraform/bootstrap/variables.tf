variable "project_name" {
  description = "Prefix for the state bucket name."
  type        = string
  default     = "devops-challenge"
}

variable "aws_region" {
  description = "Region for the state bucket."
  type        = string
  default     = "us-east-1"
}
