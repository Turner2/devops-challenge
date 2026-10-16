# Production settings. Nothing secret lives here.
aws_region         = "us-east-1"
kubernetes_version = "1.36"
az_count           = 2

# Cost trade-off for this challenge: one NAT gateway saves ~$33/month.
# Set to false for one NAT per AZ (no single point of failure for outbound traffic).
single_nat_gateway = true

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 4

git_repository_url = "https://github.com/Turner2/devops-challenge.git"
git_branch         = "main"

# Open for the review period so assessors can see pipeline runs (read-only without login).
jenkins_allowed_cidrs = ["0.0.0.0/0"]
