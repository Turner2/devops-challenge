output "role_arn" {
  value = aws_iam_role.this.arn
}

output "release_status" {
  value = helm_release.this.status
}
