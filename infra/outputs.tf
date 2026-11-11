output "app_url" {
  description = "Open this in your browser"
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "alb_dns_name" {
  description = "The load balancer's own address. Try it directly: it should time out"
  value       = aws_lb.app.dns_name
}

output "instance_id" {
  description = "For Session Manager: aws ssm start-session --target <this>"
  value       = aws_instance.app.id
}

output "db_endpoint" {
  description = "The database's private address. Try reaching it from your VM: you cannot."
  value       = aws_db_instance.app.address
}

output "deploy_role_arn" {
  description = "Goes into GitHub as the AWS_DEPLOY_ROLE_ARN variable"
  value       = aws_iam_role.deploy.arn
}

output "ecr_repository_url" {
  description = "Where the pipeline pushes images"
  value       = aws_ecr_repository.app.repository_url
}
