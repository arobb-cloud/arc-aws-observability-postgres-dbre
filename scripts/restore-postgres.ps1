param(
    [string]$BackupFile
)

docker cp `
  $BackupFile `
  dbre-postgres:/tmp/restore.sql

docker exec -i dbre-postgres psql `
  -U appuser `
  -d appdb `
  -f /tmp/restore.sql

Write-Host "Restore completed."