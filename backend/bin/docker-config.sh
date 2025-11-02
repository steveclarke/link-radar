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
export LR_IMAGE_NAME="lr-backend"
export LR_GHCR_REGISTRY="ghcr.io/steveclarke"
export LR_GHCR_REPO="${LR_GHCR_REGISTRY}/${LR_IMAGE_NAME}"
export LR_DEFAULT_PLATFORM="linux/amd64"

################################################################################
# Helper Functions
################################################################################

# Colors for output
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
nc='\033[0m'

log() {
  echo -e "${green}==>${nc} ${1}"
}

error() {
  echo -e "${red}Error:${nc} ${1}" >&2
  exit 1
}

warn() {
  echo -e "${yellow}Warning:${nc} ${1}"
}

info() {
  echo -e "${blue}Info:${nc} ${1}"
}

################################################################################
# Configuration Functions
################################################################################

# Get version from VERSION file
# Args: $1 - script directory
# Sets: lr_version (global variable)
get_version() {
  local script_dir="${1}"
  local version_file="${script_dir}/../VERSION"

  if [ ! -f "${version_file}" ]; then
    error "VERSION file not found at ${version_file}"
  fi

  lr_version=$(cat "${version_file}" | tr -d '[:space:]')

  if [ -z "${lr_version}" ]; then
    error "VERSION file is empty"
  fi

  log "Version: ${lr_version}"
}

# Get build context directory
# Args: $1 - script directory
# Returns: Path to build context (backend directory)
get_build_context() {
  local script_dir="${1}"
  echo "${script_dir}/.."
}
