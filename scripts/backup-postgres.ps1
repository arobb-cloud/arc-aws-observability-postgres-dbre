$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$backupFile = "..\backups\postgres\appdb_$timestamp.sql"

docker exec dbre-postgres pg_dump `
  -U appuser `
  -d appdb `
  -f /tmp/appdb_backup.sql

docker cp `
  dbre-postgres:/tmp/appdb_backup.sql `
  $backupFile

Write-Host "Backup completed:"
Write-Host $backupFile