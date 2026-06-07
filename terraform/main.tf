# This phase intentionally creates no AWS resources yet.
# This validates Terraform provider access to AWS.

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "billing_alarm_test" {
  alarm_name          = "${var.project_name}-${var.environment}-estimated-charges-test"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Test CloudWatch alarm for estimated AWS charges greater than 1 USD"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
}