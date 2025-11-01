#!/usr/bin/env bash

################################################################################
# Docker Configuration and Helper Functions
################################################################################
#
# Shared configuration and utilities for Docker build and push scripts.
# Centralizes image names, registry URLs, and common functions.
#
################################################################################

################################################################################
# Configuration Constants
################################################################################

# Image configuration (exported for use by sourcing scripts)
export IMAGE_NAME="lr-backend"
export GHCR_REGISTRY="ghcr.io/steveclarke"
export GHCR_REPO="${GHCR_REGISTRY}/${IMAGE_NAME}"
export DEFAULT_PLATFORM="linux/amd64"

################################################################################
# Helper Functions
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${GREEN}==>${NC} ${1}"
}

error() {
  echo -e "${RED}Error:${NC} ${1}" >&2
  exit 1
}

warn() {
  echo -e "${YELLOW}Warning:${NC} ${1}"
}

info() {
  echo -e "${BLUE}Info:${NC} ${1}"
}

################################################################################
# Configuration Functions
################################################################################

# Get version from VERSION file
# Args: $1 - script directory
# Sets: version (global variable)
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

# Get build context directory
# Args: $1 - script directory
# Returns: Path to build context (backend directory)
get_build_context() {
  local script_dir="${1}"
  echo "${script_dir}/.."
}
