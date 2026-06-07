variable "aws_region" {
  description = "AWS region for project resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and naming resources"
  type        = string
  default     = "arc-aws-observability-postgres-dbre"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner or portfolio identifier"
  type        = string
  default     = "arobb-cloud"
}

variable "alert_email" {
  description = "Email address to receive SNS alerts"
  type        = string
}