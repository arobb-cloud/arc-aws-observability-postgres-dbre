# Deployment Guide

## 1. Prerequisites

Before deploying the project, install and configure:

* AWS account with appropriate permissions
* AWS CLI
* Terraform
* Docker Desktop
* Git
* GitHub account

Verify the required tools:

```powershell
aws --version
terraform version
docker --version
git --version
```

---

## 2. Clone the Repository

```powershell
cd C:\<project-root>

git clone https://github.com/arobb-cloud/arc-aws-observability-postgres-dbre.git

cd arc-aws-observability-postgres-dbre
```

---

## 3. Configure AWS Authentication

Verify that the AWS CLI can authenticate successfully:

```powershell
aws sts get-caller-identity
```

Confirm that the account ID and AWS identity are the intended deployment target before continuing.

---

## 4. Configure Terraform Variables

Navigate to the Terraform directory:

```powershell
cd terraform
```

Copy the example variables file:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with environment-specific values such as:

```hcl
aws_region   = "us-east-1"
project_name = "arc-aws-observability-postgres-dbre"
environment  = "dev"
owner        = "portfolio-owner"
alert_email  = "your-email@example.com"
```

`terraform.tfvars` is excluded from Git and should not be committed.

---

## 5. Initialize Terraform

```powershell
terraform init
```

Expected result:

```text
Terraform has been successfully initialized!
```

---

## 6. Format and Validate Terraform

```powershell
terraform fmt -check -recursive
terraform validate
```

Expected validation result:

```text
Success! The configuration is valid.
```

---

## 7. Review the Terraform Plan

```powershell
terraform plan
```

Review all proposed resources before applying the configuration.

The observability stack includes:

* SNS alert topic
* SNS email subscription
* CloudWatch billing alarm
* CloudWatch dashboard
* CloudTrail
* S3 bucket for CloudTrail logs
* S3 encryption
* S3 versioning
* S3 public-access protection

---

## 8. Deploy AWS Infrastructure

```powershell
terraform apply
```

Review the plan and enter:

```text
yes
```

when prompted.

After deployment, review the Terraform outputs:

```powershell
terraform output
```

---

## 9. Confirm SNS Subscription

AWS sends a confirmation message to the email address configured for the SNS subscription.

Open the message and confirm the subscription before relying on email alert notifications.

---

## 10. Validate AWS Observability Resources

Verify the following resources in the AWS console:

* CloudWatch dashboard
* CloudWatch billing alarm
* SNS alert topic and confirmed subscription
* CloudTrail trail
* CloudTrail S3 log bucket

Confirm that the CloudTrail trail is actively logging.

---

## 11. Deploy the Docker PostgreSQL Platform

Return to the repository root and navigate to the Docker directory:

```powershell
cd ..\docker
```

Start the services:

```powershell
docker compose up -d
```

Verify them:

```powershell
docker ps
```

Expected services:

```text
dbre-postgres
dbre-pgadmin
```

The PostgreSQL container should report a healthy status.

---

## 12. Validate PostgreSQL

Run:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

A successful query confirms that PostgreSQL and the initialization script are functioning.

---

## 13. Access pgAdmin

Open:

```text
http://localhost:8080
```

Register the PostgreSQL container using:

```text
Host: postgres
Port: 5432
Database: appdb
Username: appuser
```

Use the password configured for the local Docker environment.

---

## 14. Validate GitHub Actions

Open the repository in GitHub and select:

```text
Actions
```

Verify successful execution of:

* Terraform Validate
* Docker Compose Validate

Both workflows should display a successful status.

---

## 15. Stop the Local Docker Platform

To stop the containers while preserving persistent volumes:

```powershell
docker compose down
```

To remove containers and associated Docker volumes:

```powershell
docker compose down -v
```

Use the second command only when persistent PostgreSQL data is no longer required.

---

## 16. Destroy AWS Infrastructure

When the AWS environment is no longer needed:

```powershell
cd ..\terraform

terraform plan -destroy
terraform destroy
```

Review the destruction plan carefully before confirming.

CloudTrail may continue writing log objects while the trail is active. Terraform dependency handling should remove the trail before removing its backing S3 resources.

---

## Deferred Enhancement

VPC Flow Logs are intentionally deferred from the current implementation and may be added in a future version of the project.
