# Plan 4: Branch Protection Configuration

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** [LR002-P4: Configure Branch Protections](https://clevertakes.superthread.com/card/131)  
**Status:** Ready to Execute

## Goal

Configure GitHub branch protections for the `main` branch to enforce the workflow documented in Plan 3. Learn what each protection setting does by configuring manually, then capture the configuration as a `gh` CLI script for future repos.

## Why This Matters

Branch protection:
- **Enforces PR workflow** - No direct pushes to main
- **Requires reviews** - Quality gate before merging
- **Enables CI checks** - Status checks must pass (Phase 2)
- **Maintains clean history** - Squash merges only
- **Prevents mistakes** - Can't accidentally push to main
- **Team-ready** - Protection works for 1 person or 50

This is crucial infrastructure that enables safe, controlled deployments.

## Protection Settings to Configure

### 1. Require Pull Requests
**What it does:** Prevents direct commits to main; all changes via PR  
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

### Step 1: Understand Branch Protection

**Time Estimate:** 30 minutes

**Research Checklist:**
- [ ] Read GitHub branch protection documentation
- [ ] Understand what each setting does technically
- [ ] Document how settings interact with each other
- [ ] Research best practices for solo development
- [ ] Research how to scale protections for teams
- [ ] Answer: What's the minimum viable protection set?
- [ ] Answer: Which settings block you vs which help you?
- [ ] Answer: What happens when CI checks fail?
- [ ] Answer: Can you bypass protections when needed?

### Step 2: Configure Protections Manually

**Time Estimate:** 30 minutes

**Configuration Checklist:**
- [ ] Navigate to GitHub repository Settings → Branches
- [ ] Click "Add rule" for `main` branch
- [ ] Enable "Require a pull request before merging"
- [ ] Set "Require approvals" to 1
- [ ] Enable "Dismiss stale pull request approvals when new commits pushed"
- [ ] Enable "Require status checks to pass before merging"
- [ ] Enable "Require branches to be up to date before merging"
- [ ] Enable "Require conversation resolution before merging"
- [ ] Enable "Require linear history"
- [ ] Configure "Include administrators" (start disabled for flexibility)
- [ ] Set "Allow force pushes" to Nobody
- [ ] Disable "Allow deletions"
- [ ] Save branch protection rule

**Documentation While Configuring:**
- [ ] Take screenshots or notes of each section
- [ ] Document what each checkbox does
- [ ] Note any confusing settings
- [ ] Think about why each matters

Navigate to GitHub repository settings:
1. Go to `Settings` → `Branches`
2. Click `Add rule` for `main` branch
3. Configure each setting:

**Recommended Settings:**

```
Branch name pattern: main

☑ Require a pull request before merging
  ☑ Require approvals: 1
  ☑ Dismiss stale pull request approvals when new commits are pushed
  ☐ Require review from Code Owners (not needed for solo)

☑ Require status checks to pass before merging
  ☑ Require branches to be up to date before merging
  Status checks (will add in Phase 2):
    - conventional-commits
    - required-labels
    - yaml-lint

☑ Require conversation resolution before merging

☑ Require linear history

☐ Require signed commits (optional, can add later)

☐ Include administrators (for now, allow yourself to bypass)
  Note: Enable this once you're comfortable with the workflow

☑ Allow force pushes: Nobody
☑ Allow deletions: Disabled
```

**As you configure:**
- Take screenshots or notes
- Document what each checkbox does
- Note any confusing settings
- Think about why each matters

### Step 3: Test the Protections

**Time Estimate:** 30 minutes

**Testing Checklist:**
- [ ] Test 1: Try direct push to main (should be rejected)
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
git checkout main
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

### Step 4: Understand the API Structure

**Time Estimate:** 30 minutes

**API Research Checklist:**
- [ ] Read `gh api` documentation
- [ ] Review branch protection API endpoint documentation
- [ ] View current protection rules with: `gh api repos/{owner}/{repo}/branches/main/protection`
- [ ] Understand the JSON payload structure
- [ ] Note required vs optional fields
- [ ] Document API endpoint structure
- [ ] Document authentication requirements

Research how to replicate your configuration via GitHub API:

**Useful commands to explore:**
```bash
# View current protection rules
gh api repos/{owner}/{repo}/branches/main/protection

# View just the payload structure
gh api repos/{owner}/{repo}/branches/main/protection --jq '.'
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
# GitHub Branch Protection Setup Script
# Configures main branch protection for LinkRadar workflow
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

echo "Setting up branch protection for main branch in $REPO..."

# Configure branch protection for main
gh api repos/"$REPO"/branches/main/protection \
  --method PUT \
  --field required_pull_request_reviews='{
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  }' \
  --field required_status_checks='{
    "strict": true,
    "contexts": []
  }' \
  --field required_conversation_resolution='{"required": true}' \
  --field required_linear_history='{"required": true}' \
  --field enforce_admins=false \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false

echo ""
echo "✅ Branch protection configured for main!"
echo ""
echo "Settings applied:"
echo "  ✓ Require pull requests with 1 approval"
echo "  ✓ Dismiss stale reviews on new commits"
echo "  ✓ Require status checks (contexts empty, add in Phase 2)"
echo "  ✓ Require branches to be up to date"
echo "  ✓ Require conversation resolution"
echo "  ✓ Require linear history"
echo "  ✓ Admins can bypass (for emergencies)"
echo "  ✓ No force pushes allowed"
echo "  ✓ Branch deletion disabled"
echo ""
echo "View settings: https://github.com/$REPO/settings/branches"
echo ""
echo "Note: Status checks will be added in Phase 2 when CI workflows are created."
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
# Branch Protection Setup Guide

## Overview

Why branch protection matters and what it enforces.

## Protection Settings Explained

### Require Pull Requests
**What it does:** [Technical explanation]
**Why we use it:** [Practical benefit]
**How it works:** [User experience]

[Repeat for each setting]

### Settings Summary

| Setting | Enabled | Why |
|---------|---------|-----|
| Require PR | ✅ | Enforces review workflow |
| Require approvals | ✅ (1) | Quality gate |
| Status checks | ✅ | CI must pass (Phase 2) |
| Conversation resolution | ✅ | Address all feedback |
| Linear history | ✅ | Clean Git history |
| Enforce admins | ❌ | Allow emergency bypass |
| Force pushes | ❌ | Prevent history rewrites |
| Deletions | ❌ | Prevent accidental deletion |

## Manual Setup (Learning Path)

### Step-by-Step Instructions

1. Navigate to GitHub Settings
2. Click Branches
3. Add rule for 'main'
4. Configure each setting...

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
- API endpoint used
- JSON payload structure
- Each protection setting

### Customizing the Script

How to modify for different needs:
- Different approval counts
- Additional status checks
- Stricter admin enforcement

## Testing Protection

### Verify It Works

Test scenarios to confirm protection:
1. Try direct push (should fail)
2. Create PR (should succeed)
3. Try merge without approval (should fail)
4. Self-approve and merge (should succeed)

### Expected Behavior

What you should see in each scenario.

## Working With Protected Branches

### Daily Workflow

How protection affects your normal workflow:
1. Always create feature branch
2. Push and create PR
3. Approve your own PR
4. Merge via squash

### Emergency Bypass

When and how to bypass (admin only):
- Critical production fixes
- How to bypass responsibly
- Re-enable protections after

### Status Checks (Phase 2)

What happens when CI checks are added:
- PR blocked until checks pass
- How to fix failing checks
- Override when needed

## Common Issues

### Can't Push to Main

Error message and solution.

### PR Won't Merge

Common reasons and fixes.

### Status Checks Never Complete

Troubleshooting (for Phase 2).

## For Future Projects

### Lifting to New Repos

How to use this script for other projects:
1. Run setup script with new repo
2. Adjust settings as needed
3. Test with dummy PR

### Team Scaling

Additional settings for larger teams:
- Require code owner reviews
- More approvals required
- Stricter admin enforcement
- Branch restrictions

## Next Steps

After setup:
- Verify with test PR
- Update development workflow
- Prepare for Phase 2 CI checks

## References

- GitHub Branch Protection docs
- GitHub API docs
- gh CLI documentation
```

## Deliverables

- [ ] Branch protections configured on main branch
- [ ] Protection settings tested with PRs
- [ ] `project/guides/github/branch-protection/setup.sh` - Working automation script
- [ ] `project/guides/github/branch-protection/guide.md` - Complete documentation
- [ ] Script tested and verified
- [ ] Superthread card #131 moved to "Done"

## Success Criteria

- ✅ Main branch protected from direct pushes
- ✅ PRs require approval before merge
- ✅ Linear history enforced
- ✅ Automation script recreates settings correctly
- ✅ Guide documents all settings with explanations
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

- Start with protections disabled for admins so you can bypass if needed
- Enable admin enforcement once comfortable
- Status check contexts array is empty now, Phase 2 will populate it
- The script makes it trivial to set up protection in new repos
- This protects against mistakes while learning the workflow

