# Incident Response Runbook

## 1. Purpose

This runbook defines the operational response procedure for incidents affecting the `arc-aws-observability-postgres-dbre` portfolio environment.

The procedure covers incidents involving:

* AWS observability resources
* CloudWatch alarms
* SNS notifications
* CloudTrail
* Docker containers
* PostgreSQL
* pgAdmin
* Terraform
* GitHub Actions

The objective is to detect, investigate, mitigate, recover, validate, and document an incident while preserving useful troubleshooting evidence.

---

## 2. Incident Response Workflow

```text
Detect
  |
  v
Validate
  |
  v
Assess Impact
  |
  v
Collect Evidence
  |
  v
Isolate
  |
  v
Mitigate / Recover
  |
  v
Validate Recovery
  |
  v
Document
```

Avoid immediately restarting, rebuilding, or deleting resources before collecting relevant evidence whenever practical.

---

## 3. Initial Incident Record

Record the following information when beginning an investigation:

```text
Incident start time:
Detection source:
Affected component:
Observed symptom:
Error message:
Initial impact:
AWS account:
AWS region:
Container status:
Actions taken:
Recovery time:
Probable/root cause:
Follow-up action:
```

Do not include passwords, credentials, tokens, or other secrets in incident documentation.

---

## 4. Validate the Environment

### AWS Identity

Before making AWS changes:

```powershell
aws sts get-caller-identity
```

Confirm that the intended AWS account is being used.

The project's default AWS region is:

```text
us-east-1
```

### Terraform State

```powershell
terraform -chdir=terraform state list
```

### Docker State

```powershell
docker ps
docker ps -a
```

### Repository State

```powershell
git status
```

---

## 5. Determine the Affected Layer

Classify the incident before making changes.

Possible layers include:

```text
AWS
 |
 +-- CloudWatch
 +-- SNS
 +-- CloudTrail
 +-- S3
 |
Terraform
 |
Docker
 |
 +-- PostgreSQL
 +-- pgAdmin
 |
PostgreSQL
 |
Backup / Restore
 |
GitHub Actions
```

Investigate the smallest affected layer first.

---

## 6. AWS Alert Investigation

If the incident originated from a CloudWatch/SNS notification:

1. Record the alarm name and notification time.
2. Open the CloudWatch alarm.
3. Review the alarm state.
4. Review the associated metric.
5. Confirm the SNS topic associated with the alarm.
6. Determine whether the alarm represents a genuine condition or a test condition.

The current project's implemented CloudWatch alarm monitors the AWS Billing `EstimatedCharges` metric.

The alert path is:

```text
AWS Billing Metric
       |
       v
CloudWatch Alarm
       |
       v
    SNS Topic
       |
       v
Email Notification
```

Do not interpret the billing alarm as PostgreSQL availability monitoring.

---

## 7. CloudTrail Investigation

Use CloudTrail when the incident may involve AWS configuration or API activity.

Review events around the incident timestamp and identify:

* event time
* event source
* event name
* AWS identity
* affected resource
* source information
* success or failure status

Use the event timeline to determine whether an AWS API operation corresponds with the observed incident.

CloudTrail logs are also delivered to the project's dedicated S3 bucket.

---

## 8. PostgreSQL Incident Investigation

### Check Container State

```powershell
docker ps
docker ps -a
```

Expected PostgreSQL container:

```text
dbre-postgres
```

### Check PostgreSQL Logs

```powershell
docker logs --tail 100 dbre-postgres
```

For live log observation:

```powershell
docker logs -f dbre-postgres
```

Exit live log monitoring with `Ctrl+C`.

### Check PostgreSQL Readiness

```powershell
docker exec dbre-postgres pg_isready -U appuser -d appdb
```

### Validate Database Access

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT now();"
```

### Validate Application Health Data

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

### Review Database Activity

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT pid, usename, state, query FROM pg_stat_activity;"
```

Record relevant evidence before restarting the container when practical.

---

## 9. PostgreSQL Container Recovery

If the PostgreSQL container is stopped:

```powershell
docker start dbre-postgres
```

Alternatively, start the Compose environment:

```powershell
docker compose -f docker\docker-compose.yml up -d
```

Monitor recovery:

```powershell
docker ps
```

Wait until PostgreSQL reports:

```text
healthy
```

Then validate database access:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

A running container alone does not prove successful recovery.

---

## 10. pgAdmin Incident Investigation

Expected pgAdmin container:

```text
dbre-pgadmin
```

Check status:

```powershell
docker ps
```

Review logs:

```powershell
docker logs --tail 100 dbre-pgadmin
```

Confirm PostgreSQL is healthy before treating the problem as a pgAdmin-specific incident.

Within the Docker environment, the PostgreSQL host should be:

```text
postgres
```

rather than `localhost`.

---

## 11. Data Loss or Corruption

If expected PostgreSQL data has been deleted, modified incorrectly, or otherwise requires recovery:

1. Avoid unnecessary additional database changes.
2. Determine the scope of affected data.
3. Identify the appropriate validated backup.
4. Record the backup filename and timestamp.
5. Follow:

```text
runbooks/postgres-backup-restore-runbook.md
```

6. Validate recovered database objects and data.
7. Record the recovery result.

Do not assume that successful execution of a restore command proves successful recovery.

---

## 12. Terraform Incident Investigation

Before changing infrastructure:

```powershell
aws sts get-caller-identity
```

Then:

```powershell
terraform -chdir=terraform validate
terraform -chdir=terraform state list
terraform -chdir=terraform plan
```

If the plan contains unexpected deletion or replacement:

**Do not apply it.**

Investigate the difference between:

* Terraform configuration
* Terraform state
* actual AWS resources
* variable configuration

Avoid manually removing resources from Terraform state merely to bypass an infrastructure error.

---

## 13. GitHub Actions Failure

If a validation workflow fails:

1. Open the failed GitHub Actions run.
2. Identify the failed step.
3. Capture the relevant error.
4. Reproduce the validation locally.

### Terraform

```powershell
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate
```

### Docker Compose

```powershell
docker compose -f docker\docker-compose.yml config
```

Resolve the local issue before pushing another change.

---

## 14. Destructive Operations

Do not use destructive operations as the first troubleshooting action.

Examples include:

```powershell
terraform -chdir=terraform destroy
```

and:

```powershell
docker compose -f docker\docker-compose.yml down -v
```

The `-v` option removes persistent Docker volumes and can delete PostgreSQL data.

Before a destructive operation:

1. Confirm the target environment.
2. Determine whether data must be preserved.
3. Create or verify a backup when appropriate.
4. Review the Terraform destruction plan where applicable.
5. Record the reason for the operation.

---

## 15. Recovery Validation

An incident is not resolved solely because a service starts.

Validate the affected layer.

### Docker

```powershell
docker ps
```

### PostgreSQL

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

### Terraform

```powershell
terraform -chdir=terraform plan
```

For a deployed environment with no intentional configuration changes, investigate unexpected drift before declaring infrastructure recovery complete.

### AWS

Verify the affected resource through the appropriate AWS service and, when applicable, review CloudTrail for the resulting API activity.

---

## 16. Incident Closure

Before closing the incident, record:

* what failed
* when the failure occurred
* how it was detected
* impact
* evidence collected
* probable or confirmed cause
* remediation performed
* recovery validation
* preventive action, if applicable

Use the distinction:

```text
Symptom != Root Cause
```

For example:

```text
Symptom:
PostgreSQL unavailable

Immediate cause:
Container stopped

Recovery:
Container restarted

Validation:
Health check returned healthy and SQL query succeeded

Root cause:
Manual container stop during controlled failure simulation
```

---

## 17. Post-Incident Review

For significant incidents or controlled failure exercises, consider:

1. Was the incident detected quickly?
2. Did existing monitoring provide useful evidence?
3. Were logs sufficient?
4. Was recovery documented?
5. Was the backup usable?
6. Did recovery meet expectations?
7. Could automation reduce recovery time?
8. Is an additional alarm, metric, or runbook needed?

The goal is not only to restore service but to improve the reliability of the environment after each incident.

---

## 18. Related Documentation

Refer to:

```text
docs/architecture.md
docs/deployment-guide.md
docs/troubleshooting-guide.md
runbooks/postgres-backup-restore-runbook.md
```

for additional architecture, deployment, troubleshooting, and database-recovery information.
