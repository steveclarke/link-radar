#!/bin/bash
# GitHub Branch Ruleset Setup Script
# Configures default branch ruleset for LinkRadar workflow
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Admin access to repository
#
# Usage:
#   ./setup.sh [owner/repo]
#
# Example:
#   ./setup.sh steveclarke/link-radar

set -e

REPO="${1:-steveclarke/link-radar}"  # Default or from argument

echo "Setting up branch ruleset for default branch in $REPO..."
echo ""

# Create the branch ruleset
gh api repos/"$REPO"/rulesets \
  --method POST \
  -f name="Master Branch Protection" \
  -f enforcement="active" \
  -f target="branch" \
  -f bypass_actors='[{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}]' \
  -f conditions='{"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}}' \
  -f rules='[
    {
      "type": "deletion"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "non_fast_forward"
    }
  ]' > /dev/null

echo "✅ Branch ruleset configured for default branch!"
echo ""
echo "Settings applied:"
echo "  ✓ Ruleset name: Master Branch Protection"
echo "  ✓ Enforcement: Active"
echo "  ✓ Target: Default branch"
echo "  ✓ Require pull requests with 1 approval"
echo "  ✓ Dismiss stale reviews on new commits"
echo "  ✓ Require last push approval"
echo "  ✓ Require linear history"
echo "  ✓ Repository admins can bypass (in PRs only)"
echo "  ✓ Block force pushes"
echo "  ✓ Restrict deletions"
echo ""
echo "⚠️  Status checks NOT configured yet (no CI workflows exist)"
echo "    Will be added in Phase 2: conventional-commits, required-labels, yaml-lint"
echo ""
echo "View settings: https://github.com/$REPO/settings/rules"
echo ""
echo "Notes:"
echo "  • Actor ID 5 = Repository Admin role"
echo "  • Bypass mode 'pull_request' = bypass only available in PR context"
echo "  • ~DEFAULT_BRANCH = targets whatever branch is set as default"
echo "  • Status checks rule excluded - add in Phase 2 when CI workflows exist"

