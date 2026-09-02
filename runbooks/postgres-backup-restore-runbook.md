# PostgreSQL Backup and Restore Runbook

## 1. Purpose

This runbook documents the backup and restore procedure for the PostgreSQL database used by the `arc-aws-observability-postgres-dbre` project.

The current environment uses:

* Docker Desktop
* Docker Compose
* PostgreSQL 16
* PostgreSQL container: `dbre-postgres`
* Database: `appdb`
* Database user: `appuser`
* PowerShell backup and restore scripts

The objective is to create repeatable logical backups and validate that those backups can be restored successfully.

A backup should not be considered reliable until a restore has been tested.

---

## 2. Backup Architecture

The backup process is:

```text
PowerShell Script
      |
      v
docker exec
      |
      v
pg_dump inside dbre-postgres
      |
      v
/tmp/appdb_backup.sql
      |
      v
docker cp
      |
      v
backups/postgres/appdb_<timestamp>.sql
```

The backup is created using PostgreSQL `pg_dump` inside the running container and then copied to the host filesystem.

---

## 3. Backup Location

Backups are stored under:

```text
backups/postgres/
```

The backup script generates timestamped filenames using:

```text
appdb_yyyyMMdd_HHmmss.sql
```

Example:

```text
appdb_20260614_185807.sql
```

Database backup files are local operational artifacts and should not be committed to the public Git repository.

---

## 4. Prerequisites

Before running a backup or restore:

1. Docker Desktop must be running.
2. The PostgreSQL container must exist.
3. The PostgreSQL container should be healthy.
4. The `appdb` database must be accessible.
5. Run the scripts from the `scripts` directory unless otherwise specified.

Verify the PostgreSQL container:

```powershell
docker ps
```

Expected container:

```text
dbre-postgres
```

The PostgreSQL container should report:

```text
healthy
```

Verify database connectivity:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT now();"
```

---

# 5. Create a PostgreSQL Backup

Navigate to the scripts directory:

```powershell
cd scripts
```

Run:

```powershell
.\backup-postgres.ps1
```

The script performs the following operation inside the PostgreSQL container:

```text
pg_dump
  -U appuser
  -d appdb
  -f /tmp/appdb_backup.sql
```

The resulting SQL file is then copied from:

```text
dbre-postgres:/tmp/appdb_backup.sql
```

to:

```text
..\backups\postgres\appdb_<timestamp>.sql
```

---

## 6. Expected Backup Output

A successful execution should display output similar to:

```text
Backup completed:
..\backups\postgres\appdb_20260614_185807.sql
```

Verify the backup file:

```powershell
Get-ChildItem ..\backups\postgres
```

Confirm that a new timestamped SQL file exists.

---

## 7. Validate the Backup File

Verify the file exists and has a nonzero size:

```powershell
Get-Item ..\backups\postgres\appdb_*.sql |
    Select-Object Name, Length, LastWriteTime
```

A zero-byte or unexpectedly small backup should be investigated before relying on it.

The presence of the file alone does not prove that it can be restored.

---

# 8. Restore a PostgreSQL Backup

The restore script requires the path to a backup file.

From the `scripts` directory, run:

```powershell
.\restore-postgres.ps1 -BackupFile "..\backups\postgres\<backup-file>.sql"
```

Example:

```powershell
.\restore-postgres.ps1 -BackupFile "..\backups\postgres\appdb_20260614_185807.sql"
```

The script copies the selected backup into the PostgreSQL container:

```text
Host backup file
      |
      v
docker cp
      |
      v
dbre-postgres:/tmp/restore.sql
```

It then executes:

```text
psql
  -U appuser
  -d appdb
  -f /tmp/restore.sql
```

inside the container.

---

## 9. Expected Restore Output

The script completes with:

```text
Restore completed.
```

This message confirms that the script reached its final command.

It does not by itself prove that every SQL statement restored successfully.

Review PowerShell, Docker, and PostgreSQL output for errors before declaring the restore successful.

---

# 10. Validate the Restore

After restoration, verify database connectivity:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT now();"
```

Verify the project schema and tables:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "\dt app.*"
```

Validate the health-check data:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT * FROM app.health_check;"
```

If the backup was created as part of a controlled recovery test, also verify any specific records that were intentionally deleted or modified before the restore.

A restore is considered successful only after expected database objects and data have been validated.

---

# 11. Controlled Recovery Test

A useful recovery-validation exercise is:

```text
Create or identify test data
        |
        v
Create backup
        |
        v
Modify or delete test data
        |
        v
Confirm simulated data loss
        |
        v
Restore backup
        |
        v
Validate recovered data
```

Only use disposable project data for destructive recovery exercises.

Do not perform this procedure against production data.

---

## 12. Example Recovery Validation

Before backup, inspect:

```sql
SELECT * FROM app.health_check;
```

Create the backup.

Then deliberately modify or delete controlled test data.

Confirm the data changed.

Restore the selected backup.

Run:

```sql
SELECT * FROM app.health_check;
```

and verify that the expected data has returned.

This validates recovery rather than backup creation alone.

---

# 13. Backup Failure Troubleshooting

If the backup script fails, first verify the container:

```powershell
docker ps
```

Then verify PostgreSQL:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT now();"
```

Confirm `pg_dump` exists:

```powershell
docker exec dbre-postgres pg_dump --version
```

Review whether the host backup directory exists:

```powershell
Test-Path ..\backups\postgres
```

If necessary:

```powershell
New-Item -ItemType Directory -Force ..\backups\postgres
```

Retry:

```powershell
.\backup-postgres.ps1
```

---

# 14. Restore Failure Troubleshooting

If the restore fails, validate the requested backup path:

```powershell
Test-Path "..\backups\postgres\<backup-file>.sql"
```

Verify PostgreSQL is running:

```powershell
docker ps
```

Verify database access:

```powershell
docker exec -it dbre-postgres psql -U appuser -d appdb -c "SELECT current_database();"
```

Possible failure points include:

* incorrect backup filename
* incorrect relative path
* failed `docker cp`
* stopped PostgreSQL container
* database authentication failure
* SQL errors during restore
* conflicts with existing database objects

Review the actual `psql` output to identify the failed SQL statement where applicable.

---

# 15. Important Restore Behavior

The current backup is a plain-text logical SQL dump created by `pg_dump`.

The restore process executes that SQL against the existing `appdb` database.

The current script does not:

* drop and recreate `appdb`
* automatically remove existing schemas or tables
* perform point-in-time recovery
* restore Docker volumes
* restore PostgreSQL physical data files
* perform an automated integrity comparison

Because existing objects may already be present, some restore scenarios can generate object-exists or data-conflict errors.

The operator must review restore output and validate the resulting database state.

---

# 16. Protect Backup Files

The `backups/postgres/` directory should remain excluded from source control.

Verify:

```powershell
git status
```

If backup files unexpectedly appear as untracked Git content, verify `.gitignore`.

Example:

```powershell
git check-ignore -v backups/postgres/appdb_20260614_185807.sql
```

Do not commit database backup files to the public repository.

---

# 17. Destructive Docker Operations

The following operation removes Docker volumes:

```powershell
docker compose -f docker\docker-compose.yml down -v
```

For PostgreSQL, this can delete persistent database storage.

Before running it:

1. Determine whether the existing database data is required.
2. Create a fresh backup if necessary.
3. Verify the backup exists.
4. Prefer testing the restore before intentionally removing persistent data.

To stop the environment while preserving volumes, use:

```powershell
docker compose -f docker\docker-compose.yml down
```

---

# 18. Backup and Recovery Principles

The operational principles demonstrated by this project are:

```text
Backup created
      !=
Recovery proven
```

A more complete recovery workflow is:

```text
Create backup
      |
      v
Verify backup artifact
      |
      v
Perform controlled restore
      |
      v
Validate recovered objects
      |
      v
Validate recovered data
      |
      v
Document result
```

The recovery test is the evidence that the backup procedure is operationally useful.

---

# 19. Current Limitations

The current implementation is intentionally lightweight and designed for a portfolio environment.

Current limitations include:

* backups are manually initiated
* backups are stored locally
* backup encryption is not separately implemented
* no remote/object-storage backup destination
* no scheduled retention process
* no point-in-time recovery
* no automated restore test
* no backup-monitoring alert
* no automated integrity validation

These are candidates for future improvements rather than current implementation claims.

---

# 20. Future Enhancements

Possible future enhancements include:

* scheduled PostgreSQL backups
* backup retention automation
* encrypted backup storage
* Amazon S3 backup storage
* automated restore testing
* backup-success/failure monitoring
* backup integrity checks
* RPO/RTO definitions
* managed Amazon RDS PostgreSQL backup and recovery
* PostgreSQL WAL-based point-in-time recovery

---

## Related Documentation

See:

```text
docs/architecture.md
docs/deployment-guide.md
docs/troubleshooting-guide.md
runbooks/incident-response-runbook.md
```

for related architecture, deployment, troubleshooting, and incident-response procedures.
