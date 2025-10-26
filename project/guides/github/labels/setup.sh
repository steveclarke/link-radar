#!/bin/bash
# GitHub Labels Setup Script
# Sets up type + area label taxonomy for LinkRadar
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Repository name set (modify REPO variable below)
#
# Usage:
#   ./setup.sh

set -e

REPO="steveclarke/link-radar"  # Update with your repo

echo "Setting up GitHub labels for $REPO..."

# Function to create or update label
create_label() {
  local name="$1"
  local color="$2"
  local description="$3"

  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$description" \
    --force
}

# Type Labels
echo "Creating type labels..."
create_label "type: feat" "0052CC" "New features"
create_label "type: fix" "FF5630" "Bug fixes"
create_label "type: docs" "6B778C" "Documentation changes"
create_label "type: style" "00B8D9" "Code style/formatting"
create_label "type: refactor" "6554C0" "Code restructuring"
create_label "type: test" "36B37E" "Test additions/changes"
create_label "type: chore" "FFAB00" "Build, tools, dependencies"

# Area Labels
echo "Creating area labels..."
create_label "area: backend" "FF8B00" "Rails API backend"
create_label "area: extension" "00C7B7" "Browser extension"
create_label "area: frontend" "36B37E" "Frontend SPA"
create_label "area: cli" "0065FF" "CLI tool"
create_label "area: infrastructure" "6B778C" "Docker, deployment, CI/CD"
create_label "area: project" "8777D9" "Project docs and planning"

echo "✅ Labels setup complete!"
echo "View labels: https://github.com/$REPO/labels"

