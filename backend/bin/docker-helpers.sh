#!/usr/bin/env bash

# Docker helper functions for Link Radar backend

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log a message with color
log() {
  echo -e "${GREEN}==>${NC} ${1}"
}

# Log an error and exit
error() {
  echo -e "${RED}Error:${NC} ${1}" >&2
  exit 1
}

# Log a warning
warn() {
  echo -e "${YELLOW}Warning:${NC} ${1}"
}

# Log an info message
info() {
  echo -e "${BLUE}Info:${NC} ${1}"
}

# Get version from VERSION file
get_version() {
  local script_dir="${1}"
  local version_file="${script_dir}/../VERSION"

  if [ ! -f "${version_file}" ]; then
    error "VERSION file not found at ${version_file}"
  fi

  version=$(cat "${version_file}" | tr -d '[:space:]')

  if [ -z "${version}" ]; then
    error "VERSION file is empty"
  fi

  log "Version: ${version}"
}

# Get GHCR repository URL
get_repo() {
  # GitHub Container Registry repository
  # Format: ghcr.io/USERNAME/REPO_NAME
  repo="ghcr.io/steveclarke/lr-backend"

  info "Repository: ${repo}"
}

