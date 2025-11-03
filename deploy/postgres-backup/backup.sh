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
    CUTOFF_DATE=$(date -d "${REMOVE_BEFORE} days ago" +%Y-%m-%d 2>/dev/null || date -v-${REMOVE_BEFORE}d +%Y-%m-%d)
    
    s3cmd ls "s3://${BUCKET}/" | while read -r line; do
        BACKUP_FILE=$(echo "$line" | awk '{print $4}')
        BACKUP_DATE=$(echo "$BACKUP_FILE" | grep -oP 'linkradar_\K\d{4}-\d{2}-\d{2}' || echo "")
        
        if [ -n "$BACKUP_DATE" ] && [ "$BACKUP_DATE" \< "$CUTOFF_DATE" ]; then
            echo "Removing old backup: $BACKUP_FILE"
            s3cmd del "$BACKUP_FILE"
        fi
    done
fi

echo "========================================="
echo "Backup completed: $(date)"
echo "========================================="

