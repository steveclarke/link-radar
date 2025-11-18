# Postgres Backup Container

Custom backup solution for Postgres 18 that dumps the database and uploads to S3-compatible storage (Vultr Object Storage).

## What It Does

Runs `pg_dump` every 3 hours, compresses the output, uploads to Vultr S3, and automatically cleans up backups older than 7 days.

## Testing Manually

```bash
docker compose exec postgres-backup /backup.sh
```

## Restoring from Backup

```bash
# Download from Vultr S3
s3cmd get s3://lr-backups/linkradar_YYYY-MM-DD_HH-MM-SS.sql.gz

# Restore to database
gunzip < linkradar_YYYY-MM-DD_HH-MM-SS.sql.gz | docker compose exec -T postgres psql -U linkradar linkradar_production
```

## Deploying Changes

When you modify the Dockerfile or backup.sh:

```bash
git pull
bin/up --build postgres-backup  # Force rebuild
```

Or rebuild all build-based services:

```bash
bin/up --build
```

## Configuration

Configured via `env/postgres.env` and `env/backup.env`. Image builds automatically on first startup.

