#!/usr/bin/env bash
set -euo pipefail

################################################################################
# PostgreSQL Backup to S3
################################################################################
#
# OVERVIEW
# --------
# Automated PostgreSQL backup script that dumps the database, compresses it,
# and uploads to S3-compatible storage (Vultr, Backblaze B2, AWS S3, etc.).
# Automatically cleans up backups older than REMOVE_BEFORE days.
#
# USAGE
# -----
#   /backup.sh                    Run backup once
#   (or via cron: 0 */3 * * *)    Every 3 hours
#
# CONFIGURATION
# -------------
# Postgres: POSTGRES_HOST, POSTGRES_PORT, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
# S3: ACCESS_KEY_ID, SECRET_ACCESS_KEY, BUCKET, HOST_BASE, HOST_BUCKET
# Retention: REMOVE_BEFORE (days, 0=keep all)
#
################################################################################

# Colors for output
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[1;33m'
red='\033[0;31m'
nc='\033[0m'

# Configuration from environment variables
POSTGRES_HOST=${POSTGRES_HOST:-postgres}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}
POSTGRES_DB=${POSTGRES_DB:-postgres}

ACCESS_KEY_ID=${ACCESS_KEY_ID:?ACCESS_KEY_ID is required}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY:?SECRET_ACCESS_KEY is required}
BUCKET=${BUCKET:?BUCKET is required}
HOST_BASE=${HOST_BASE:?HOST_BASE is required}
HOST_BUCKET=${HOST_BUCKET:-"%(bucket)s.${HOST_BASE}"}
REMOVE_BEFORE=${REMOVE_BEFORE:-0}

# Generate backup filename
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="linkradar_${TIMESTAMP}.sql.gz"
BACKUP_PATH="/tmp/${FILENAME}"

################################################################################
# Main Orchestration
################################################################################

main() {
  echo "========================================="
  log "Starting backup: $(date)"
  info "Database: ${POSTGRES_DB}@${POSTGRES_HOST}"
  info "Destination: s3://${BUCKET}/"
  echo "========================================="
  
  generate_s3_config
  dump_database
  upload_to_s3
  cleanup_local_backup
  cleanup_old_backups
  
  echo "========================================="
  log "Backup completed: $(date)"
  echo "========================================="
}

################################################################################
# Helper Functions
################################################################################

log() { echo -e "${green}==>${nc} ${1}"; }
info() { echo -e "${blue}Info:${nc} ${1}"; }
warn() { echo -e "${yellow}Warning:${nc} ${1}"; }
error() { echo -e "${red}Error:${nc} ${1}" >&2; exit 1; }

################################################################################
# Core Backup Functions
################################################################################

generate_s3_config() {
  info "Generating s3cmd configuration..."
  
  sed -e "s|__ACCESS_KEY_ID__|${ACCESS_KEY_ID}|g" \
      -e "s|__SECRET_ACCESS_KEY__|${SECRET_ACCESS_KEY}|g" \
      -e "s|__HOST_BASE__|${HOST_BASE}|g" \
      -e "s|__HOST_BUCKET__|${HOST_BUCKET}|g" \
      /root/.s3cfg.template > /root/.s3cfg
}

dump_database() {
  info "Dumping database..."
  
  export PGPASSWORD="${POSTGRES_PASSWORD}"
  pg_dump -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | gzip > "${BACKUP_PATH}"
  unset PGPASSWORD
  
  local backup_size
  backup_size=$(du -h "${BACKUP_PATH}" | cut -f1)
  log "Backup created: ${FILENAME} (${backup_size})"
}

upload_to_s3() {
  info "Uploading to S3..."
  
  if ! s3cmd put "${BACKUP_PATH}" "s3://${BUCKET}/${FILENAME}"; then
    error "Failed to upload backup to S3"
  fi
  
  log "Upload successful"
}

cleanup_local_backup() {
  rm -f "${BACKUP_PATH}"
  info "Local backup file removed"
}

cleanup_old_backups() {
  if [ "${REMOVE_BEFORE}" -gt 0 ]; then
    info "Cleaning up backups older than ${REMOVE_BEFORE} days..."
    
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "${REMOVE_BEFORE} days ago" +%s 2>/dev/null || date -v-"${REMOVE_BEFORE}"d +%s 2>/dev/null || echo "")
    
    if [ -n "$cutoff_timestamp" ]; then
      s3cmd ls "s3://${BUCKET}/" | while read -r date_part time_part _ filename; do
        if [ -n "$filename" ]; then
          local file_date file_time file_timestamp
          file_date=$(echo "$date_part" | tr -d '-')
          file_time=$(echo "$time_part" | tr -d ':' | cut -d'.' -f1)
          file_timestamp=$(date -d "${file_date:0:4}-${file_date:4:2}-${file_date:6:2} ${file_time:0:2}:${file_time:2:2}:${file_time:4:2}" +%s 2>/dev/null || echo "0")
          
          if [ "$file_timestamp" -gt 0 ] && [ "$file_timestamp" -lt "$cutoff_timestamp" ]; then
            info "Removing old backup: $filename"
            s3cmd del "$filename"
          fi
        fi
      done
    else
      warn "Old backup cleanup skipped (date command not compatible)"
    fi
  fi
}

################################################################################
# Script Execution
################################################################################

main "$@"

