# Troubleshooting Guide

## 1. Purpose

This guide provides troubleshooting procedures for the `arc-aws-observability-postgres-dbre` project.

The environment combines:

* Terraform-managed AWS observability resources
* Amazon CloudWatch
* Amazon SNS
* AWS CloudTrail
* Amazon S3
* Docker Compose
* PostgreSQL 16
* pgAdmin
* PowerShell backup and restore automation
* GitHub Actions validation workflows

The troubleshooting approach follows an operational workflow:

```text
Detect
  |
  v
Validate
  |
  v
Collect Evidence
  |
  v
Isolate the Failure
  |
  v
Remediate
  |
  v
Validate Recovery
```

Avoid making destructive changes until the affected layer and likely failure condition have been identified.

---

# 2. Initial Environment Validation

Before investigating a specific component, establish the current state of the environment.

## Verify AWS Identity

```powershell
aws sts get-caller-identity
```

Confirm that the command references the intended AWS account before performing Terraform operations.

## Verify Terraform

```powershell
terraform version
terraform -chdir=terraform validate
```

## Verify Docker

```powershell
docker version
docker ps
```

## Verify Git Repository State

```powershell
git status
```

These checks help distinguish configuration problems from authentication, tooling, container-runtime, or repository problems.

---

# 3. PostgreSQL Container Is Not Running

## Symptoms

`docker ps` does not show:

```text
dbre-postgres
```

or the container is missing while pgAdmin or other Docker services are running.

## Diagnosis

Check all containers, including stopped containers:

```powershell
docker ps -a
```

Inspect PostgreSQL logs:

```powershell
docker logs dbre-postgres
```

Inspect detailed container state:

```powershell
docker inspect dbre-postgres
```

## Common Causes

Possible causes include:

* container was manually stopped
* Docker Desktop restarted
* invalid environment configuration
* PostgreSQL initialization failure
* host port conflict
* persistent-volume problem
* container startup error

## Recovery

Start the existing container:

```powershell
docker start dbre-postgres
```

Alternatively, start the Compose environment:

```powershell
docker compose -f docker\docker-compose.yml up -d
```

Verify:

```powershell
docker ps
```

The PostgreSQL container should eventually report:

```text
healthy
```

## Recovery Validation

Verify database access:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT now();"
```

Then validate the project health-check table:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

Recovery is not considered complete until the database is reachable and expected data is accessible.

---

# 4. PostgreSQL Container Is Running but Unhealthy

## Symptoms

`docker ps` shows the PostgreSQL container running but reports:

```text
unhealthy
```

## Diagnosis

Review container logs:

```powershell
docker logs dbre-postgres
```

Check recent logs:

```powershell
docker logs --tail 100 dbre-postgres
```

Inspect health-check results:

```powershell
docker inspect dbre-postgres
```

Look for the container's health information and recent health-check failures.

## Validate PostgreSQL Directly

```powershell
docker exec -it dbre-postgres pg_isready -U appuser -d appdb
```

A healthy PostgreSQL service should report that it is accepting connections.

## Possible Causes

* PostgreSQL is still starting
* database initialization failed
* incorrect database/user configuration
* storage problem
* PostgreSQL process failure
* health-check configuration does not match the database configuration

Resolve the underlying condition and then recheck:

```powershell
docker ps
```

---

# 5. PostgreSQL Connection Failure

## Symptoms

A connection attempt returns errors such as:

```text
connection refused
```

or authentication/database errors.

## Diagnosis

Verify container status:

```powershell
docker ps
```

Verify PostgreSQL readiness:

```powershell
docker exec -it dbre-postgres pg_isready -U appuser -d appdb
```

Test database access directly:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT current_database();"
```

## Validate Configuration

Confirm that the configured values correspond to the Docker environment:

```text
Database: appdb
Username: appuser
Port: 5432
```

Do not expose active passwords while collecting troubleshooting evidence.

---

# 6. pgAdmin Cannot Connect to PostgreSQL

## Symptoms

pgAdmin is available in the browser but cannot establish a connection to PostgreSQL.

## Validate Containers

```powershell
docker ps
```

Both containers should be running:

```text
dbre-postgres
dbre-pgadmin
```

PostgreSQL should report a healthy status.

## Validate pgAdmin Connection Settings

When pgAdmin runs inside the same Docker Compose environment, use the PostgreSQL Docker service name as the host.

Typical settings are:

```text
Host: postgres
Port: 5432
Database: appdb
Username: appuser
```

Do not use `localhost` as the PostgreSQL host from inside the pgAdmin container. Inside the pgAdmin container, `localhost` refers to pgAdmin itself.

## Review Logs

PostgreSQL:

```powershell
docker logs dbre-postgres
```

pgAdmin:

```powershell
docker logs dbre-pgadmin
```

## Validate PostgreSQL Independently

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT version();"
```

If this succeeds but pgAdmin still fails, focus the investigation on pgAdmin connection configuration rather than PostgreSQL availability.

---

# 7. PostgreSQL Initialization Objects Are Missing

## Symptoms

A query such as:

```sql
SELECT * FROM app.health_check;
```

returns an error indicating that the schema or table does not exist.

## Diagnosis

Connect to the database:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb
```

Inspect schemas:

```sql
\dn
```

Inspect application tables:

```sql
\dt app.*
```

## Likely Cause

PostgreSQL Docker initialization scripts normally execute when the database data directory is first initialized.

If an existing persistent volume was already initialized before `init.sql` was introduced or changed, restarting the container does not automatically rerun the initialization script.

## Resolution

For an existing environment, apply the required SQL manually or restore the required database objects.

Deleting the PostgreSQL volume and recreating the environment will cause initialization to occur again, but this is destructive.

Do not run:

```powershell
docker compose -f docker\docker-compose.yml down -v
```

unless deletion of the persistent database volume is intentional and any required data has been protected.

---

# 8. Inspect PostgreSQL Activity

For operational investigation, query PostgreSQL's activity view:

```sql
SELECT pid, usename, state, query
FROM pg_stat_activity;
```

This provides visibility into active and idle sessions and the SQL associated with those sessions.

Other basic validation queries include:

```sql
SELECT version();
SELECT current_database();
SELECT now();
SELECT * FROM app.health_check;
```

These checks help determine whether the issue exists at the container, PostgreSQL service, database, or object level.

---

# 9. PostgreSQL Backup Failure

## Symptoms

The backup PowerShell script fails or no expected SQL backup appears under:

```text
backups/postgres/
```

## Initial Checks

Verify PostgreSQL is running:

```powershell
docker ps
```

Verify database access:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT now();"
```

Verify `pg_dump` is available:

```powershell
docker exec dbre-postgres pg_dump --version
```

## Run the Backup Script

From the repository root:

```powershell
.\scripts\backup-postgres.ps1
```

Review any PowerShell, Docker, or PostgreSQL errors.

## Verify Backup Creation

```powershell
Get-ChildItem backups\postgres
```

Confirm that a new timestamped SQL dump was created.

## Important

The existence of a backup file does not prove that the database is recoverable.

A usable backup strategy requires restore testing.

---

# 10. PostgreSQL Restore Failure

## Symptoms

The restore script reports an error, or restored objects/data are not present afterward.

## Validate the Backup

Confirm the requested backup exists:

```powershell
Get-ChildItem backups\postgres
```

Verify PostgreSQL is running:

```powershell
docker ps
```

## Review the Restore Process

The project's restore process copies the SQL dump into the PostgreSQL container and executes it using `psql`.

Potential failure points include:

* incorrect host backup path
* failed `docker cp`
* incorrect container path
* PostgreSQL authentication failure
* target database does not exist
* SQL errors during restore
* existing database objects conflict with restored objects

Review the script output carefully rather than assuming the restore completed successfully.

## Validate Recovery

After restoration:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb
```

Then verify expected objects and data:

```sql
\dt app.*

SELECT * FROM app.health_check;
```

Where a recovery test uses additional test data, verify that data explicitly.

A restore should only be considered successful after the recovered data has been validated.

For the full recovery procedure, see:

```text
runbooks/postgres-backup-restore-runbook.md
```

---

# 11. Terraform Validation Failure

## Symptoms

```powershell
terraform -chdir=terraform validate
```

returns configuration errors.

## Troubleshooting Sequence

Format the configuration:

```powershell
terraform -chdir=terraform fmt
```

Initialize Terraform:

```powershell
terraform -chdir=terraform init
```

Validate again:

```powershell
terraform -chdir=terraform validate
```

## Common Causes

* HCL syntax errors
* missing braces
* incorrect resource arguments
* provider initialization problems
* incompatible provider/resource configuration
* malformed variable or output definitions

Read the Terraform error carefully. Terraform generally identifies the affected file and line number.

---

# 12. Terraform Cannot Authenticate to AWS

## Symptoms

Terraform reports credential, token, authorization, or AWS identity errors.

## Validate AWS CLI Authentication

```powershell
aws sts get-caller-identity
```

If this command fails, resolve AWS authentication before troubleshooting Terraform resources.

## Confirm Terraform Target

Review:

```powershell
terraform -chdir=terraform plan
```

Verify that the provider is using the intended AWS account and region.

The project's default region is:

```text
us-east-1
```

Do not apply or destroy infrastructure until the target account is confirmed.

---

# 13. Terraform Plan Shows Unexpected Changes

## Symptoms

`terraform plan` proposes unexpected replacement, deletion, or creation of resources.

## Response

Do not apply the plan immediately.

First inspect:

```powershell
terraform -chdir=terraform state list
```

Then review:

```powershell
terraform -chdir=terraform plan
```

Compare the proposed changes with the current Terraform source.

Possible causes include:

* configuration changes
* resource changes made directly in AWS
* variable changes
* provider behavior changes
* resource drift
* state/configuration mismatch

Terraform plans should be treated as a review gate before infrastructure changes are executed.

---

# 14. Terraform Destroy Fails on the CloudTrail S3 Bucket

## Symptoms

Terraform reports an S3 error similar to:

```text
BucketNotEmpty
```

while destroying the CloudTrail log bucket.

## Background

The CloudTrail bucket has versioning enabled, and CloudTrail can continue writing objects while the trail is active.

The Terraform bucket configuration uses `force_destroy` to support removal of stored objects during teardown.

## Troubleshooting

First review the remaining Terraform state:

```powershell
terraform -chdir=terraform state list
```

Then rerun:

```powershell
terraform -chdir=terraform destroy
```

If the bucket continues to fail, inspect the S3 bucket for:

* current objects
* object versions
* delete markers

Also verify that CloudTrail is no longer actively writing to the bucket.

Do not remove the S3 resource from Terraform state merely to bypass the error. Doing so can leave unmanaged AWS resources behind.

Resolve the underlying S3 object/version condition and then complete the Terraform-managed destruction.

---

# 15. CloudWatch Alarm Does Not Send Email

## Symptoms

The CloudWatch alarm changes state but no email notification is received.

## Check SNS Subscription

In AWS SNS, verify that the email subscription is:

```text
Confirmed
```

A newly created email subscription requires confirmation before SNS can deliver notifications.

## Verify Alarm Action

Confirm that the CloudWatch alarm uses the project's SNS topic as its alarm action.

The expected path is:

```text
CloudWatch Alarm
       |
       v
    SNS Topic
       |
       v
Confirmed Email Subscription
```

## Additional Checks

* inspect spam/junk folders
* confirm the configured email address
* inspect SNS subscription status
* verify the alarm actually entered the state required to invoke the action

---

# 16. CloudTrail Is Not Delivering Logs

## Symptoms

CloudTrail exists but expected log objects are not appearing in the S3 bucket.

## Verify Trail Configuration

Confirm that:

* the trail is enabled
* logging is active
* the configured S3 bucket is correct
* the trail includes the expected regions/events

## Verify S3 Permissions

The CloudTrail bucket policy must allow the CloudTrail service to:

* retrieve the bucket ACL
* write log objects to the appropriate AWS account path

## Verify Bucket Protection

The bucket uses:

* AES-256 server-side encryption
* versioning
* public-access blocking

These controls should not prevent correctly authorized CloudTrail service delivery.

Use CloudTrail and S3 console information together to isolate whether the issue is trail configuration, permissions, or log delivery.

---

# 17. CloudTrail Lifecycle Rule Is Missing

## Symptoms

The CloudTrail S3 bucket exists but no expected retention rule appears under the S3 lifecycle configuration.

## Validate Terraform

```powershell
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

Confirm that the Terraform configuration contains the CloudTrail lifecycle resource.

The intended portfolio retention policy is:

```text
Current objects:       90 days
Noncurrent versions:   30 days
Incomplete uploads:     7 days
```

If Terraform proposes creating the lifecycle configuration, review the plan and apply it when appropriate.

After deployment, verify the lifecycle rule through the S3 bucket's Management settings.

---

# 18. CloudWatch Dashboard Appears Empty

## Symptoms

The dashboard exists but the billing widget does not immediately display expected data.

## Checks

Confirm:

* the dashboard exists in the intended AWS account
* the widget is configured for the correct region
* the metric is `AWS/Billing` → `EstimatedCharges`
* the currency dimension is `USD`

Billing metrics behave differently from high-frequency infrastructure metrics and should not be interpreted as real-time system telemetry.

The billing alarm and dashboard are primarily used in this project to demonstrate the CloudWatch monitoring and SNS notification architecture.

---

# 19. GitHub Actions Terraform Workflow Fails

## Symptoms

The Terraform validation workflow displays a failed GitHub Actions run.

## Review the Failed Job

Open:

```text
Repository → Actions → Terraform workflow → Failed run
```

Identify the failing step.

The workflow validates operations such as:

* Terraform formatting
* Terraform initialization
* Terraform validation

## Reproduce Locally

Run:

```powershell
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate
```

Resolve the local error before pushing another change.

This keeps local validation and CI validation aligned.

---

# 20. GitHub Actions Docker Workflow Fails

## Symptoms

The Docker validation workflow reports a failed run.

## Reproduce Locally

Run:

```powershell
docker compose -f docker\docker-compose.yml config
```

This validates the Compose configuration without starting the services.

## Common Causes

* invalid YAML
* incorrect indentation
* missing environment-variable references
* malformed service configuration
* invalid volume or dependency configuration

Correct the local configuration, validate again, commit the change, and push it to GitHub.

---

# 21. Port Conflict

## Symptoms

Docker reports that port `5432` or `8080` is already allocated.

## Identify the Conflict

On Windows:

```powershell
Get-NetTCPConnection -LocalPort 5432 -ErrorAction SilentlyContinue
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
```

A locally installed PostgreSQL instance may already be using port `5432`, or another application may be using port `8080`.

## Resolution

Either:

* stop the conflicting service, or
* intentionally change the host-side port mapping in the Compose configuration.

After making a configuration change:

```powershell
docker compose -f docker\docker-compose.yml config
```

Then recreate the services as appropriate.

---

# 22. Docker Environment Variables

Local credentials and environment-specific configuration should not be committed to Git.

The repository provides:

```text
docker/.env.example
```

as a configuration template.

If the environment fails because required variables are missing, verify that the required local environment configuration exists and corresponds to the variables referenced by `docker-compose.yml`.

Never replace the example file with active credentials and commit it to the repository.

---

# 23. Git Shows Sensitive or Local Files

## Symptoms

`git status` shows files such as:

```text
terraform.tfstate
terraform.tfstate.backup
terraform.tfvars
.env
database backup files
.terraform/
```

## Response

Do not commit them.

Check whether Git ignores the file:

```powershell
git check-ignore -v <path>
```

Determine whether the file is already tracked:

```powershell
git ls-files <path>
```

If a sensitive file was previously committed, adding it to `.gitignore` does not remove it from repository history.

Treat accidental credential exposure as a security incident and rotate affected credentials where appropriate.

---

# 24. Operational Incident Workflow

For unexpected failures, use the following sequence.

## Step 1 — Detect

Identify the symptom through:

* CloudWatch
* SNS
* Docker health
* application/database behavior
* GitHub Actions
* user or operational report

## Step 2 — Validate

Confirm the failure independently.

Examples:

```powershell
docker ps
docker logs dbre-postgres
aws sts get-caller-identity
terraform -chdir=terraform plan
```

## Step 3 — Collect Evidence

Capture relevant:

* timestamps
* error messages
* logs
* container state
* PostgreSQL activity
* CloudWatch state
* CloudTrail events
* Terraform output
* CI workflow output

## Step 4 — Isolate

Determine the affected layer:

```text
AWS
Terraform
CloudWatch/SNS
CloudTrail/S3
Docker
PostgreSQL
pgAdmin
Backup/Restore
GitHub Actions
```

## Step 5 — Remediate

Make the smallest appropriate change that addresses the identified cause.

## Step 6 — Validate Recovery

Confirm that the affected service has returned to the expected state.

For PostgreSQL, for example:

```powershell
docker ps
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

## Step 7 — Document

Record:

* symptom
* impact
* evidence
* root or probable cause
* corrective action
* validation
* preventive improvement

For a formal incident-response workflow, see:

```text
runbooks/incident-response-runbook.md
```

---

# 25. Destructive Operations

Use additional caution with operations that can delete infrastructure or persistent data.

Examples include:

```powershell
terraform -chdir=terraform destroy
```

and:

```powershell
docker compose -f docker\docker-compose.yml down -v
```

Before performing destructive operations:

1. Confirm the target AWS account or Docker environment.
2. Review the Terraform destruction plan where applicable.
3. Determine whether persistent database data is required.
4. Create and validate backups where necessary.
5. Confirm that the operation affects only the intended project resources.

---

# 26. Escalation and Investigation Principle

The troubleshooting strategy for this project is evidence-driven.

Avoid immediately restarting, rebuilding, or deleting resources simply because a component is unhealthy.

Whenever practical:

```text
Observe first
      ↓
Collect evidence
      ↓
Identify affected layer
      ↓
Determine probable cause
      ↓
Remediate
      ↓
Validate recovery
```

This preserves troubleshooting evidence and creates a more reliable operational process.
