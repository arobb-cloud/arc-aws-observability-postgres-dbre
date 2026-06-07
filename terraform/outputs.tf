output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID currently being used"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_provider_region" {
  description = "AWS provider region currently being used"
  value       = data.aws_region.current.region
}

output "sns_alert_topic_arn" {
  description = "SNS topic ARN for CloudWatch alert notifications"
  value       = aws_sns_topic.alerts.arn
}