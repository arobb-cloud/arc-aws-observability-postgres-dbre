data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# This phase intentionally creates no AWS resources yet.
# This validates Terraform provider access to AWS.