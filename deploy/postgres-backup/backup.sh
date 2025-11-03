#!/bin/bash
set -euo pipefail

# Postgres Backup Script for S3-compatible storage
# Dumps database, compresses, uploads to S3, and cleans up old backups

# Configuration from environment variables
POSTGRES_HOST=${POSTGRES_HOST:-postgres}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}
POSTGRES_DB=${POSTGRES_DB:-postgres}

# S3 Configuration
ACCESS_KEY_ID=${ACCESS_KEY_ID:?ACCESS_KEY_ID is required}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY:?SECRET_ACCESS_KEY is required}
BUCKET=${BUCKET:?BUCKET is required}
HOST_BASE=${HOST_BASE:?HOST_BASE is required}
HOST_BUCKET=${HOST_BUCKET:-"%(bucket)s.${HOST_BASE}"}
REMOVE_BEFORE=${REMOVE_BEFORE:-0}

# Generate timestamp for filename
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="linkradar_${TIMESTAMP}.sql.gz"
BACKUP_PATH="/tmp/${FILENAME}"

echo "========================================="
echo "Starting backup: $(date)"
echo "Database: ${POSTGRES_DB}@${POSTGRES_HOST}"
echo "Destination: s3://${BUCKET}/"
echo "========================================="

# Generate s3cmd config from template
echo "Generating s3cmd configuration..."
sed -e "s|__ACCESS_KEY_ID__|${ACCESS_KEY_ID}|g" \
    -e "s|__SECRET_ACCESS_KEY__|${SECRET_ACCESS_KEY}|g" \
    -e "s|__HOST_BASE__|${HOST_BASE}|g" \
    -e "s|__HOST_BUCKET__|${HOST_BUCKET}|g" \
    /root/.s3cfg.template > /root/.s3cfg

# Run pg_dump with compression
echo "Dumping database..."
export PGPASSWORD="${POSTGRES_PASSWORD}"
pg_dump -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | gzip > "${BACKUP_PATH}"
unset PGPASSWORD

BACKUP_SIZE=$(du -h "${BACKUP_PATH}" | cut -f1)
echo "Backup created: ${FILENAME} (${BACKUP_SIZE})"

# Upload to S3
echo "Uploading to S3..."
s3cmd put "${BACKUP_PATH}" "s3://${BUCKET}/${FILENAME}"

# Clean up local file
rm -f "${BACKUP_PATH}"
echo "Local backup file removed"

# Remove old backups if REMOVE_BEFORE is set
if [ "${REMOVE_BEFORE}" -gt 0 ]; then
    echo "Cleaning up backups older than ${REMOVE_BEFORE} days..."
    CUTOFF_TIMESTAMP=$(date -d "${REMOVE_BEFORE} days ago" +%s 2>/dev/null || date -v-${REMOVE_BEFORE}d +%s 2>/dev/null || echo "")
    
    if [ -n "$CUTOFF_TIMESTAMP" ]; then
        s3cmd ls "s3://${BUCKET}/" | while read -r date_part time_part size_part filename; do
            if [ -n "$filename" ]; then
                FILE_DATE=$(echo "$date_part" | tr -d '-')
                FILE_TIME=$(echo "$time_part" | tr -d ':' | cut -d'.' -f1)
                FILE_TIMESTAMP=$(date -d "${FILE_DATE:0:4}-${FILE_DATE:4:2}-${FILE_DATE:6:2} ${FILE_TIME:0:2}:${FILE_TIME:2:2}:${FILE_TIME:4:2}" +%s 2>/dev/null || echo "0")
                
                if [ "$FILE_TIMESTAMP" -gt 0 ] && [ "$FILE_TIMESTAMP" -lt "$CUTOFF_TIMESTAMP" ]; then
                    echo "Removing old backup: $filename"
                    s3cmd del "$filename"
                fi
            fi
        done
    else
        echo "Note: Old backup cleanup skipped (date command not compatible)"
    fi
fi

echo "========================================="
echo "Backup completed: $(date)"
echo "========================================="

