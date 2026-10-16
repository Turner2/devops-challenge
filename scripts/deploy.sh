#!/usr/bin/env bash
# One command to stand up everything:
#   1. terraform/bootstrap         -> S3 bucket for remote state (first run only)
#   2. terraform/environments/prod -> VPC, EKS, ALB controller, CloudWatch, ECR, Jenkins
# Jenkins then builds and deploys the app by itself (first build starts ~1 min after boot,
# then again on every push to the tracked branch).
#
# Usage: ./scripts/deploy.sh [extra terraform apply args, e.g. -auto-approve]
# Needs: terraform >= 1.10, AWS credentials with admin rights in the target account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-us-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="devops-challenge-tfstate-$ACCOUNT_ID" # same name terraform/bootstrap creates
echo "==> Using AWS identity: $(aws sts get-caller-identity --query Arn --output text)"

echo "==> [1/2] Remote state bucket"
if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  echo "    s3://$STATE_BUCKET already exists, skipping bootstrap"
else
  terraform -chdir="$ROOT/terraform/bootstrap" init -input=false
  terraform -chdir="$ROOT/terraform/bootstrap" apply -input=false -auto-approve -var "aws_region=$REGION"
fi

echo "==> [2/2] Production environment (state: s3://$STATE_BUCKET)"
terraform -chdir="$ROOT/terraform/environments/prod" init -input=false -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="region=$REGION"
terraform -chdir="$ROOT/terraform/environments/prod" apply -input=false "$@"

echo
terraform -chdir="$ROOT/terraform/environments/prod" output
cat <<'EOF'

Next:
  - Open jenkins_url: the first pipeline run starts by itself about a minute after Jenkins boots.
  - When it finishes, the build description and log show the app URL.
  - Or run the app_url_command output after configure_kubectl.
EOF
