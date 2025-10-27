#!/bin/bash
# GitHub Actions Setup Script
# 
# Note: GitHub Actions settings must be configured manually via GitHub UI.
# This script documents the required settings and provides verification steps.
#
# Prerequisites:
# - Admin access to repository
#
# Usage:
#   ./setup.sh [owner/repo]
#
# Example:
#   ./setup.sh steveclarke/link-radar

set -e

REPO="${1:-steveclarke/link-radar}"

echo "GitHub Actions Setup for $REPO"
echo ""
echo "⚠️  Manual Configuration Required"
echo ""
echo "GitHub Actions settings cannot be fully automated via API."
echo "Please configure the following settings manually:"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📍 Go to: https://github.com/$REPO/settings/actions"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Required Settings:"
echo ""
echo "1. Actions permissions:"
echo "   ☑ Allow all actions and reusable workflows"
echo ""
echo "2. Workflow permissions:"
echo "   ☑ Read and write permissions"
echo "   ☑ Allow GitHub Actions to create and approve pull requests"
echo ""
echo "3. Fork pull request workflows from outside collaborators:"
echo "   ☑ Require approval for first-time contributors"
echo ""
echo "4. Artifact and log retention:"
echo "   • 90 days (default - no change needed)"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "After Configuration:"
echo ""
echo "1. Test with the workflow:"
echo "   .github/workflows/test-permissions.yml"
echo ""
echo "2. Verify by running:"
echo "   gh workflow run test-permissions.yml"
echo ""
echo "3. Check that a test issue was created"
echo ""
echo "4. Close the test issue and optionally delete test workflow"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "See guide.md for detailed documentation."
echo ""

