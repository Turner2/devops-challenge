variable "name" {
  description = "Name prefix for all network resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for the subnet discovery tags the load balancer controller reads."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "AZs to spread subnets across. At least two for EKS and the ALB."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "EKS and ALB need subnets in at least two Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per AZ, in the same order as availability_zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per AZ, in the same order as availability_zones."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheaper, single-AZ egress). false = one NAT per AZ (HA)."
  type        = bool
  default     = false
}
