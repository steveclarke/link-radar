# Plan 4: Branch Protection Configuration

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** [LR002-P4: Configure Branch Protections](https://clevertakes.superthread.com/card/131)  
**Status:** Ready to Execute

## Goal

Configure GitHub branch rulesets for the `master` branch to enforce the workflow documented in Plan 3. Learn what each ruleset setting does by configuring manually, then capture the configuration as a `gh` CLI script for future repos.

**Note:** This plan uses GitHub's modern **Branch Rulesets** system (not classic branch protection) as it's more flexible and future-proof.

## Why This Matters

Branch rulesets:
- **Enforces PR workflow** - No direct pushes to master
- **Requires reviews** - Quality gate before merging
- **Enables CI checks** - Status checks must pass (Phase 2)
- **Maintains clean history** - Squash merges only
- **Prevents mistakes** - Can't accidentally push to master
- **Team-ready** - Rules work for 1 person or 50
- **Future-proof** - Uses GitHub's modern ruleset system

This is crucial infrastructure that enables safe, controlled deployments.

## Protection Settings to Configure

### 1. Require Pull Requests
**What it does:** Prevents direct commits to master; all changes via PR  
**Why you want it:** Enforces review process and CI checks

### 2. Require Approvals
**What it does:** PR needs N approvals before merge  
**Why you want it:** Quality gate (even self-approval counts)

### 3. Require Status Checks
**What it does:** CI workflows must pass before merge  
**Why you want it:** Automated validation (Phase 2 workflows)

### 4. Require Linear History
**What it does:** Only squash or rebase merges allowed  
**Why you want it:** Clean, understandable Git history

### 5. Include Administrators
**What it does:** Apply rules to repo admins too  
**Why you want it:** Consistency (but allow bypass for emergencies)

## What You'll Create

### 1. Branch Protection Configuration
**Location:** GitHub repository settings (via UI, then CLI)

### 2. Automation Script
**Location:** `project/guides/github/branch-protection/setup.sh`

### 3. Guide Documentation
**Location:** `project/guides/github/branch-protection/guide.md`

## Implementation Steps

### Step 1: Understand Branch Rulesets

**Time Estimate:** 30 minutes

**Research Checklist:**
- [ ] Read GitHub branch rulesets documentation
- [ ] Understand the difference between rulesets and classic protection
- [ ] Understand what each ruleset setting does technically
- [ ] Document how settings interact with each other
- [ ] Research best practices for solo development
- [ ] Research how to scale rulesets for teams
- [ ] Answer: What's the minimum viable ruleset configuration?
- [ ] Answer: Which settings block you vs which help you?
- [ ] Answer: What happens when CI checks fail?
- [ ] Answer: Can you bypass rulesets when needed?
- [ ] Answer: What's the difference between "Active" and "Evaluate" enforcement?

### Step 2: Configure Ruleset Manually

**Time Estimate:** 30 minutes

**Configuration Checklist:**
- [ ] Navigate to GitHub repository Settings → Branches
- [ ] Click "Add branch ruleset" (NOT "Add classic branch protection rule")
- [ ] Set ruleset name: "Master Branch Protection"
- [ ] Set enforcement status: "Active"
- [ ] Click "Add target" → Select "Include default branch"
- [ ] Click "Add bypass" → Select "Repository admin"
- [ ] Enable "Restrict deletions"
- [ ] Enable "Require linear history"
- [ ] Enable "Require a pull request before merging"
- [ ] Set "Required approvals" to 1
- [ ] Enable "Dismiss stale pull request approvals when new commits are pushed"
- [ ] Enable "Require approval of the most recent reviewable push"
- [ ] Leave "Require status checks to pass" UNCHECKED (will add in Phase 2)
- [ ] Enable "Block force pushes"
- [ ] Save ruleset

**Documentation While Configuring:**
- [ ] Take screenshots or notes of each section
- [ ] Document what each checkbox does
- [ ] Note any confusing settings
- [ ] Think about why each matters

Navigate to GitHub repository settings:
1. Go to `Settings` → `Branches`
2. Click `Add branch ruleset` (the button on the left)
3. Configure each setting:

**Recommended Ruleset Configuration:**

```
Ruleset Name: Master Branch Protection
Enforcement status: Active

Target Branches:
  ☑ Include default branch
  (Automatically targets master - simpler and more future-proof than pattern matching)

Bypass list:
  ☑ Repository admin (for emergencies)
  Note: You can remove this later once comfortable with workflow

Rules:

☑ Restrict deletions
☑ Require linear history

☑ Require a pull request before merging
  ☑ Required approvals: 1
  ☑ Dismiss stale pull request approvals when new commits are pushed
  ☐ Require review from Code Owners (not needed for solo)
  ☑ Require approval of the most recent reviewable push
  ☐ Require conversation resolution before merging (optional)

☐ Require status checks to pass
  NOTE: Leave UNCHECKED for now - no CI workflows exist yet
  Will enable in Phase 2 with these checks:
    - conventional-commits
    - required-labels
    - yaml-lint

☑ Block force pushes

☐ Require signed commits (optional, can add later)
```

**As you configure:**
- Take screenshots or notes
- Document what each checkbox does
- Note any confusing settings
- Think about why each matters

### Step 3: Test the Protections

**Time Estimate:** 30 minutes

**Testing Checklist:**
- [ ] Test 1: Try direct push to master (should be rejected)
- [ ] Test 2: Create feature branch and push (should succeed)
- [ ] Test 3: Create PR from feature branch (should succeed)
- [ ] Test 4: Try to merge PR without approval (should be blocked)
- [ ] Test 5: Self-approve PR (should succeed)
- [ ] Test 6: Merge PR with squash (should succeed)
- [ ] Document what worked as expected
- [ ] Document any surprises
- [ ] Document protection messages you saw
- [ ] Document how the experience felt
- [ ] Clean up test branch

Verify protections work:

**Test 1: Try Direct Push**
```bash
git checkout master
echo "test" >> test.txt
git add test.txt
git commit -m "test: direct push attempt"
git push
```
Expected: **Rejected** - "protected branch hook declined"

**Test 2: Create PR Workflow**
```bash
git checkout -b test/branch-protection
echo "via PR" >> test.txt
git add test.txt
git commit -m "test: via pull request"
git push origin test/branch-protection
```
Then create PR on GitHub. Expected: **Allowed** to create PR

**Test 3: Merge Without Approval**
Try to merge the PR immediately. Expected: **Blocked** - needs approval

**Test 4: Self-Approve and Merge**
Approve your own PR. Expected: **Allowed** to merge

**Document:**
- What worked as expected
- Any surprises
- What protection messages you saw
- How the experience felt

### Step 4: Understand the Rulesets API Structure

**Time Estimate:** 30 minutes

**API Research Checklist:**
- [ ] Read `gh api` documentation
- [ ] Review branch rulesets API endpoint documentation
- [ ] View current rulesets with: `gh api repos/{owner}/{repo}/rulesets`
- [ ] View specific ruleset details
- [ ] Understand the JSON payload structure for creating rulesets
- [ ] Note required vs optional fields
- [ ] Document API endpoint structure
- [ ] Document authentication requirements
- [ ] Understand rule types and their parameters

Research how to replicate your configuration via GitHub API:

**Useful commands to explore:**
```bash
# List all rulesets for the repository
gh api repos/{owner}/{repo}/rulesets

# View a specific ruleset (get ID from list above)
gh api repos/{owner}/{repo}/rulesets/{ruleset_id}

# View the full ruleset structure with pretty printing
gh api repos/{owner}/{repo}/rulesets/{ruleset_id} --jq '.'
```

### Step 5: Create Automation Script

**Time Estimate:** 60 minutes

**Script Creation Checklist:**
- [ ] Create directory `project/guides/github/branch-protection/`
- [ ] Create file `setup.sh` in the directory
- [ ] Add script header and prerequisites documentation
- [ ] Add repository variable configuration
- [ ] Add gh API call for branch protection
- [ ] Configure required_pull_request_reviews settings
- [ ] Configure required_status_checks settings
- [ ] Configure required_conversation_resolution
- [ ] Configure required_linear_history
- [ ] Configure enforce_admins setting
- [ ] Configure restrictions to null
- [ ] Configure allow_force_pushes to false
- [ ] Configure allow_deletions to false
- [ ] Add success message with settings summary
- [ ] Add verification URL
- [ ] Add note about Phase 2 status checks
- [ ] Make script executable: `chmod +x setup.sh`

**Script Testing:**
- [ ] Disable current branch protection temporarily
- [ ] Run the script against your repository
- [ ] Verify all protections recreated correctly
- [ ] Test with PR workflow again
- [ ] Document any issues encountered
- [ ] Fix any script errors

Create `project/guides/github/branch-protection/setup.sh`:

```bash
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
#   ./setup.sh username/link-radar

set -e

REPO="${1:-username/link-radar}"  # Default or from argument

echo "Setting up branch ruleset for default branch in $REPO..."

# Note: Not used currently, but kept for reference if needed for other bypass actors
REPO_ID=$(gh api repos/"$REPO" --jq '.id')

# Create the branch ruleset
gh api repos/"$REPO"/rulesets \
  --method POST \
  -f name="Master Branch Protection" \
  -f enforcement="active" \
  -f target="branch" \
  -f bypass_actors='[{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]' \
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
  ]'

# Note: "required_status_checks" rule is NOT included in initial setup
# It will be added in Phase 2 when CI workflows are created
# To add it later, edit the ruleset in GitHub UI or use the update API

echo ""
echo "✅ Branch ruleset configured for default branch!"
echo ""
echo "Settings applied:"
echo "  ✓ Ruleset name: Master Branch Protection"
echo "  ✓ Enforcement: Active"
echo "  ✓ Target: Default branch (currently master)"
echo "  ✓ Require pull requests with 1 approval"
echo "  ✓ Dismiss stale reviews on new commits"
echo "  ✓ Require last push approval"
echo "  ✓ Require linear history"
echo "  ✓ Repository admins can bypass (for emergencies)"
echo "  ✓ Block force pushes"
echo "  ✓ Restrict deletions"
echo ""
echo "⚠️  Status checks NOT configured yet (no CI workflows exist)"
echo "    Will be added in Phase 2: conventional-commits, required-labels, yaml-lint"
echo ""
echo "View settings: https://github.com/$REPO/settings/rules"
echo ""
echo "Note: Actor ID 5 = Repository Admin role. This allows you to bypass in emergencies."
echo "Note: Using ~DEFAULT_BRANCH targets whatever branch is set as default (currently master)."
```

**Make executable:**
```bash
chmod +x project/guides/github/branch-protection/setup.sh
```

**Test the script:**
1. Disable current branch protection
2. Run the script
3. Verify protections are recreated correctly
4. Test with the PR workflow again

### Step 6: Document in Guide

**Time Estimate:** 90 minutes

**Guide Creation Checklist:**
- [ ] Create directory `project/guides/github/branch-protection/` (if not exists)
- [ ] Create file `guide.md` in the directory
- [ ] Write Overview section
- [ ] Write Protection Settings Explained section for each setting
- [ ] Create Settings Summary table
- [ ] Write Manual Setup section with step-by-step instructions
- [ ] Write Automated Setup section explaining the script
- [ ] Write Testing Protection section with verification steps
- [ ] Write Working With Protected Branches section
- [ ] Write Common Issues section with troubleshooting
- [ ] Write For Future Projects section
- [ ] Proofread and refine guide

Create `project/guides/github/branch-protection/guide.md`:

**Guide Structure:**

```markdown
# Branch Ruleset Setup Guide

## Overview

Why branch rulesets matter and what they enforce. Explains the difference between classic branch protection and modern rulesets.

## Rulesets vs Classic Protection

Brief comparison and why we chose rulesets.

## Ruleset Settings Explained

### Require Pull Requests
**What it does:** [Technical explanation]
**Why we use it:** [Practical benefit]
**How it works:** [User experience]

[Repeat for each rule type]

### Settings Summary

| Rule | Enabled | Why |
|------|---------|-----|
| Require PR | ✅ | Enforces review workflow |
| Required approvals | ✅ (1) | Quality gate |
| Last push approval | ✅ | Re-review after changes |
| Linear history | ✅ | Clean Git history |
| Bypass: Admins | ✅ | Allow emergency bypass |
| Block force pushes | ✅ | Prevent history rewrites |
| Restrict deletions | ✅ | Prevent accidental deletion |
| Status checks | ⚠️ Phase 2 | Will add when CI workflows exist |

## Manual Setup (Learning Path)

### Step-by-Step Instructions

1. Navigate to GitHub Settings
2. Click Branches
3. Click "Add branch ruleset" (NOT classic protection)
4. Configure ruleset name and enforcement
5. Set target branches
6. Configure each rule...

[Detailed walkthrough with screenshots or descriptions]

### What Each Setting Does

Detailed explanation as you click through GitHub UI.

## Automated Setup (Production Path)

### Using the Script

```bash
cd project/guides/github/branch-protection
./setup.sh your-username/your-repo
```

### Script Breakdown

Explanation of what the script does:
- Rulesets API endpoint
- JSON payload structure for rulesets
- Each rule configuration
- Bypass actors configuration

### Customizing the Script

How to modify for different needs:
- Different approval counts
- Additional status checks
- Different bypass permissions
- Multiple branch patterns

## Testing Ruleset

### Verify It Works

Test scenarios to confirm ruleset:
1. Try direct push (should fail)
2. Create PR (should succeed)
3. Try merge without approval (should fail)
4. Self-approve and merge (should succeed)

### Expected Behavior

What you should see in each scenario.

## Working With Rulesets

### Daily Workflow

How rulesets affect your normal workflow:
1. Always create feature branch
2. Push and create PR
3. Approve your own PR
4. Merge via squash

### Emergency Bypass

When and how to bypass (admin only):
- Critical production fixes
- How to bypass responsibly
- Understand enforcement modes (Active vs Evaluate)

### Status Checks (Phase 2)

What happens when CI checks are added:
- PR blocked until checks pass
- How to fix failing checks
- Adding checks to the ruleset

## Common Issues

### Can't Push to Master

Error message and solution.

### PR Won't Merge

Common reasons and fixes.

### Status Checks Never Complete

Troubleshooting (for Phase 2).

### Ruleset vs Classic Conflicts

What happens if you have both configured.

## For Future Projects

### Lifting to New Repos

How to use this script for other projects:
1. Run setup script with new repo
2. Adjust settings as needed
3. Test with dummy PR

### Organization-Wide Rulesets

How to scale to organization level:
- Creating org-level rulesets
- Repository-level overrides
- Managing multiple repos

### Team Scaling

Additional settings for larger teams:
- Require code owner reviews
- More approvals required
- Stricter bypass permissions
- Status check requirements

## Next Steps

After setup:
- Verify with test PR
- Update development workflow
- Prepare for Phase 2 CI checks

## References

- GitHub Branch Rulesets docs
- GitHub Rulesets API docs
- gh CLI documentation
- Migration guide from classic to rulesets
```

## Deliverables

- [ ] Branch ruleset configured for master branch
- [ ] Ruleset settings tested with PRs
- [ ] `project/guides/github/branch-protection/setup.sh` - Working automation script using rulesets API
- [ ] `project/guides/github/branch-protection/guide.md` - Complete documentation covering rulesets
- [ ] Script tested and verified
- [ ] Superthread card #131 moved to "Done"

## Success Criteria

- ✅ Master branch protected from direct pushes via ruleset
- ✅ PRs require approval before merge
- ✅ Linear history enforced
- ✅ Modern rulesets system used (not classic protection)
- ✅ Automation script recreates ruleset correctly
- ✅ Guide documents all ruleset settings with explanations
- ✅ Test PR successfully created and merged
- ✅ Ready for Phase 2 status checks

## Time Estimate

**Total:** ~4 hours

## Next Steps

After completing this plan:
1. Move Superthread card #131 to "Done"
2. Proceed to Plan 5 (GitHub Actions Setup)
3. All PRs now go through protected workflow

## Notes

- **Using modern rulesets** - Future-proof approach that GitHub is investing in
- **Using "Include default branch"** - Simpler and more maintainable than pattern matching. Automatically follows if you rename master → main
- **Status checks NOT configured initially** - Since no CI workflows exist yet, the "Require status checks to pass" rule is left unchecked. Will be added in Phase 2.
- Start with admin bypass enabled so you can override if needed
- The script makes it trivial to set up rulesets in new repos
- Rulesets are more flexible than classic protection (can target multiple branches with patterns)
- Actor ID 5 = Repository Admin role (used for bypass permissions)
- `~DEFAULT_BRANCH` in API = special token that targets the repository's default branch
- This protects against mistakes while learning the workflow
- Can migrate classic protection to rulesets later if you started with classic
- In Phase 2, you'll edit this ruleset to add status checks for: conventional-commits, required-labels, yaml-lint

