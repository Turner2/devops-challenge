# Jenkins controller on EC2, fully configured at boot:
#   - Jenkins, Docker, kubectl, Terraform installed by user data
#   - plugins installed with the Jenkins plugin manager
#   - admin user, global settings and the pipeline job created by
#     Configuration as Code (JCasC) + Job DSL, so there is no setup wizard
#     and no clicking around in the UI.
# The instance role is the pipeline's only AWS credential: no access keys.

data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# Admin password: generated, stored encrypted in SSM, read by the instance at boot
# ---------------------------------------------------------------------------
resource "random_password" "admin" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "admin_password" {
  name        = "/${var.name}/jenkins/admin-password"
  description = "Jenkins admin password (user: admin)"
  type        = "SecureString"
  value       = random_password.admin.result
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
resource "aws_security_group" "jenkins" {
  name        = "${var.name}-jenkins"
  description = "Jenkins controller UI"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-jenkins" }
}

resource "aws_vpc_security_group_ingress_rule" "ui" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.jenkins.id
  description       = "Jenkins UI"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Package downloads, GitHub, ECR, EKS API"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Let Jenkins reach the EKS private API endpoint from inside the VPC.
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id            = var.cluster_security_group_id
  description                  = "Kubernetes API from Jenkins"
  referenced_security_group_id = aws_security_group.jenkins.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_eip" "jenkins" {
  domain = "vpc"
  tags   = { Name = "${var.name}-jenkins" }
}

# ---------------------------------------------------------------------------
# IAM: least privilege for build, push and deploy
# ---------------------------------------------------------------------------
resource "aws_iam_role" "jenkins" {
  name = "${var.name}-jenkins"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "pipeline" {
  name = "pipeline"
  role = aws_iam_role.jenkins.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushAndScanResults"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = var.ecr_repository_arn
      },
      {
        Sid      = "EksKubeconfig"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = var.cluster_arn
      },
      {
        Sid      = "ReadAdminPassword"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = aws_ssm_parameter.admin_password.arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name}-jenkins"
  role = aws_iam_role.jenkins.name
}

# Kubernetes access: "edit" rights inside the app namespace only, not cluster-admin.
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.deploy_namespace]
  }

  depends_on = [aws_eks_access_entry.jenkins]
}

# ---------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------
# Orders the instance after var.wait_for without a module-level depends_on.
resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1          # containers on the host cannot borrow the instance role
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size_gb
    encrypted   = true
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    region             = data.aws_region.current.region
    admin_password_ssm = aws_ssm_parameter.admin_password.name
    kubernetes_version = var.kubernetes_version
    casc_yaml = templatefile("${path.module}/templates/casc.yaml.tftpl", {
      jenkins_url        = "http://${aws_eip.jenkins.public_ip}:8080/"
      git_repository_url = var.git_repository_url
      git_branch         = var.git_branch
      region             = data.aws_region.current.region
      ecr_repository_url = var.ecr_repository_url
      cluster_name       = var.cluster_name
      deploy_namespace   = var.deploy_namespace
    })
  })

  tags = { Name = "${var.name}-jenkins" }

  lifecycle {
    ignore_changes = [ami] # don't rebuild Jenkins every time a new AMI is published
  }

  depends_on = [aws_iam_role_policy.pipeline, terraform_data.wait_for]
}

resource "aws_eip_association" "jenkins" {
  instance_id   = aws_instance.jenkins.id
  allocation_id = aws_eip.jenkins.id
}

# Auto-recover the instance if the underlying host fails.
resource "aws_cloudwatch_metric_alarm" "recover" {
  alarm_name          = "${var.name}-jenkins-system-check"
  alarm_description   = "Recover Jenkins when the EC2 system status check fails"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  dimensions          = { InstanceId = aws_instance.jenkins.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = concat(["arn:${data.aws_partition.current.partition}:automate:${data.aws_region.current.region}:ec2:recover"], var.alarm_topic_arns)
}
