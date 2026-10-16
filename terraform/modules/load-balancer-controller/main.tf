# AWS Load Balancer Controller: turns the app's Kubernetes Ingress into an
# internet-facing Application Load Balancer that sends traffic straight to pod IPs.
#
# The IAM policy is vendored from the controller's release tag that matches
# `chart_version`, so the permissions and the controller version move together.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

locals {
  service_account = "aws-load-balancer-controller"
  namespace       = "kube-system"
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "Permissions for the AWS Load Balancer Controller (from release v${var.chart_version})"
  policy      = file("${path.module}/policies/iam-policy-v${var.chart_version}.json")
}

resource "aws_iam_role" "this" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = var.pod_identity_trust_policy
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

# EKS Pod Identity: the controller's service account assumes the role above.
resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = local.service_account
  role_arn        = aws_iam_role.this.arn
}

resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = local.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    clusterName    = var.cluster_name
    region         = var.region
    vpcId          = var.vpc_id
    replicaCount   = 2
    serviceAccount = {
      create = true
      name   = local.service_account
    }
    # Creates the `alb` IngressClass the app's Ingress refers to.
    createIngressClassResource = true
    ingressClass               = "alb"
  })]

  depends_on = [
    aws_eks_pod_identity_association.this,
    aws_iam_role_policy_attachment.this,
  ]
}
