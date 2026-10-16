output "url" {
  value = "http://${aws_eip.jenkins.public_ip}:8080/"
}

output "job_url" {
  value = "http://${aws_eip.jenkins.public_ip}:8080/job/product-catalog/"
}

output "instance_id" {
  value = aws_instance.jenkins.id
}

output "role_arn" {
  value = aws_iam_role.jenkins.arn
}

output "admin_password_ssm_parameter" {
  value = aws_ssm_parameter.admin_password.name
}
