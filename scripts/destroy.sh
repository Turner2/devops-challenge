#!/usr/bin/env bash
# Tear everything down.
# The ALB is created by Kubernetes (not Terraform), so the app namespace's Ingress
# is deleted first and we wait for the controller to remove the ALB. Otherwise
# the VPC cannot be deleted while the ALB and its security groups still exist.
# The state bucket (terraform/bootstrap) is kept on purpose.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-us-east-1}"
PROD="$ROOT/terraform/environments/prod"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="devops-challenge-tfstate-$ACCOUNT_ID"
terraform -chdir="$PROD" init -input=false -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" -backend-config="region=$REGION" >/dev/null

CLUSTER="$(terraform -chdir="$PROD" output -raw cluster_name 2>/dev/null || true)"
if [ -n "$CLUSTER" ] && aws eks describe-cluster --region "$REGION" --name "$CLUSTER" >/dev/null 2>&1; then
  echo "==> Removing the app Ingress so the controller deletes the ALB"
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --kubeconfig /tmp/destroy-kubeconfig >/dev/null
  KUBECONFIG=/tmp/destroy-kubeconfig kubectl delete ingress --all -n product-catalog --ignore-not-found --wait=true --timeout=5m || true
  echo "==> Waiting for the ALB to disappear"
  for _ in $(seq 1 30); do
    aws elbv2 describe-load-balancers --region "$REGION" --names product-catalog-prod >/dev/null 2>&1 || break
    sleep 10
  done
fi

terraform -chdir="$PROD" destroy -input=false "$@"
