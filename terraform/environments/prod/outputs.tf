output "region" {
  value = var.aws_region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "jenkins_url" {
  value = module.jenkins.url
}

output "jenkins_job_url" {
  value = module.jenkins.job_url
}

output "jenkins_admin_password_command" {
  description = "Run this to read the Jenkins admin password (user: admin)."
  value       = "aws ssm get-parameter --region ${var.aws_region} --name ${module.jenkins.admin_password_ssm_parameter} --with-decryption --query Parameter.Value --output text"
}

output "app_url_command" {
  description = "The ALB is created by Kubernetes on first deploy; this prints its URL."
  value       = "kubectl get ingress ${var.app_name} -n ${var.app_namespace} -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}/'"
}

output "cloudwatch_dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${module.monitoring.dashboard_name}"
}
