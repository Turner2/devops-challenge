# Production environment: wires the reusable modules together.
# A staging environment would be a copy of this folder with a different
# terraform.tfvars and backend key, not a copy of the modules.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name         = "${var.project_name}-${var.environment}"
  cluster_name = local.name
  azs          = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.azs
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]     # 10.0.0.0/24, 10.0.1.0/24
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 1)] # 10.0.16.0/20, 10.0.32.0/20
  single_nat_gateway   = var.single_nat_gateway
}

module "ecr" {
  source = "../../modules/ecr"

  name         = var.app_name
  force_delete = true # lets `terraform destroy` clean up after the review
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  cluster_admin_arns  = var.cluster_admin_arns
  log_retention_days  = var.log_retention_days
}

module "load_balancer_controller" {
  source = "../../modules/load-balancer-controller"

  cluster_name              = module.eks.cluster_name
  region                    = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  pod_identity_trust_policy = module.eks.pod_identity_trust_policy

  # Needs running nodes and the Pod Identity agent before the controller can start.
  depends_on = [module.eks]
}

# The namespace is owned by Terraform so Jenkins can be limited to it.
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/part-of"          = var.project_name
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }

  depends_on = [module.eks]
}

module "monitoring" {
  source = "../../modules/monitoring"

  name         = local.name
  cluster_name = module.eks.cluster_name
  namespace    = var.app_namespace
  app_name     = var.app_name
  service_name = var.app_name
  alb_name     = var.alb_name
  alarm_email  = var.alarm_email
}

module "jenkins" {
  source = "../../modules/jenkins"

  name                      = local.name
  vpc_id                    = module.vpc.vpc_id
  subnet_id                 = module.vpc.public_subnet_ids[0]
  allowed_cidrs             = var.jenkins_allowed_cidrs
  instance_type             = var.jenkins_instance_type
  git_repository_url        = var.git_repository_url
  git_branch                = var.git_branch
  ecr_repository_url        = module.ecr.repository_url
  ecr_repository_arn        = module.ecr.repository_arn
  cluster_name              = module.eks.cluster_name
  cluster_arn               = module.eks.cluster_arn
  cluster_security_group_id = module.eks.cluster_security_group_id
  kubernetes_version        = var.kubernetes_version
  deploy_namespace          = kubernetes_namespace_v1.app.metadata[0].name
  alarm_topic_arns          = [module.monitoring.alarm_topic_arn]

  # Start Jenkins last, so its first automatic build finds a ready cluster and ALB controller.
  depends_on = [module.load_balancer_controller]
}
