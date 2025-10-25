# Plan 5: GitHub Actions Permissions Setup

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** [LR002-P5: Set Up GitHub Actions](https://clevertakes.superthread.com/card/132)  
**Status:** Ready to Execute

## Goal

Configure GitHub Actions permissions and settings to prepare for Phase 2 (CI validation workflows) and Phase 3 (deployment trigger placeholders). Learn the permissions model, configure manually, and document for future automation.

## Why This Matters

GitHub Actions permissions:
- **Enable workflow automation** - Required for Phase 2/3 workflows
- **Control access scope** - Workflows can only do what you allow
- **Secure by default** - Proper permissions prevent security issues
- **Support CI/CD** - Workflows need read/write access for creating issues, comments, etc.

Setting this up now means Phase 2/3 workflows will "just work" when you create them.

## Permissions You'll Configure

### 1. Enable GitHub Actions
**What it does:** Allows workflows to run in the repository  
**Why you need it:** Foundation for all automation

### 2. Workflow Permissions (Read/Write)
**What it does:** Controls what workflows can access/modify  
**Why you need it:** Workflows need to create issues, add comments, update statuses

### 3. Allow GitHub Actions to Create/Approve PRs
**What it does:** Lets workflows create PRs and approve them  
**Why you need it:** Useful for automated dependency updates (future)

### 4. GITHUB_TOKEN Permissions
**What it does:** Default token permissions for workflows  
**Why you need it:** Secure access to repository resources

## What You'll Create

### 1. GitHub Actions Configuration
**Location:** GitHub repository settings (Actions section)

### 2. Documentation (Script Optional)
**Location:** `project/guides/github/actions/guide.md`

### 3. Automation Script (If Scriptable)
**Location:** `project/guides/github/actions/setup.sh`

Note: Some Actions settings may only be configurable via UI. Document both approaches.

## Implementation Steps

### Step 1: Understand GitHub Actions Permissions

**Time Estimate:** 45 minutes

**Research Checklist:**
- [ ] Read GitHub Actions security model documentation
- [ ] Read GITHUB_TOKEN automatic token documentation
- [ ] Understand permission scopes (read, write, none)
- [ ] Understand workflow permissions vs token permissions
- [ ] Read security hardening for Actions best practices
- [ ] Answer: What can workflows access by default?
- [ ] Answer: When do workflows need write access?
- [ ] Answer: How are secrets different from GITHUB_TOKEN?
- [ ] Answer: What's the principle of least privilege here?
- [ ] Document key findings

Research and document:

### Step 2: Configure Actions Settings Manually

**Time Estimate:** 30 minutes

**Configuration Checklist:**
- [ ] Navigate to GitHub repository Settings → Actions → General
- [ ] Set "Actions permissions" to "Allow all actions and reusable workflows"
- [ ] Set "Workflow permissions" to "Read and write permissions"
- [ ] Enable "Allow GitHub Actions to create and approve pull requests"
- [ ] Set "Fork pull request workflows" to "Require approval for first-time contributors"
- [ ] Verify "Artifacts and logs" retention (90 days default is fine)
- [ ] Save all settings

**Documentation While Configuring:**
- [ ] Screenshot each section
- [ ] Document what each setting does
- [ ] Note security implications
- [ ] Consider what Phase 2/3 workflows will need

Navigate to GitHub repository settings:

**Recommended Settings:**

```
Actions permissions:
  ☑ Allow all actions and reusable workflows
     (Can restrict to specific actions later if needed)

Workflow permissions:
  ☑ Read and write permissions
     ☑ Allow GitHub Actions to create and approve pull requests

Fork pull request workflows from outside collaborators:
  ☑ Require approval for first-time contributors
     (Security measure for public repos)

Artifacts and logs:
  Retention: 90 days (default)
```

**As you configure:**
- Screenshot each section
- Document what each setting does
- Note security implications
- Consider what Phase 2/3 workflows will need

### Step 3: Understand What Workflows Will Need

**Time Estimate:** 30 minutes

**Workflow Requirements Analysis:**
- [ ] Document Phase 2 workflow needs (CI validation)
- [ ] Document Phase 3 workflow needs (deployment triggers)
- [ ] List required permissions for Phase 2
- [ ] List required permissions for Phase 3
- [ ] Document why each permission is needed
- [ ] Document what happens without each permission
- [ ] Note security considerations for each permission

Based on the LR002 vision, Phase 2/3 workflows will need:

**Phase 2 (CI Validation):**
- Read PR content (title, commits, labels)
- Write comments on PRs with validation results
- Update status checks
- Read repository files (for linting)

**Phase 3 (Deployment Placeholders):**
- Read repository metadata (branch, commit, tags)
- Create GitHub Issues with deployment information
- Read workflow run information

**Required Permissions:**
- `contents: read` - Read repository files
- `pull-requests: write` - Comment on PRs
- `issues: write` - Create deployment placeholder issues
- `statuses: write` - Update status checks

**Document:**
- Why each permission is needed
- What happens without it
- Security considerations

### Step 4: Test with a Simple Workflow

**Time Estimate:** 30 minutes

**Test Workflow Creation:**
- [ ] Create `.github/workflows/` directory if not exists
- [ ] Create `test-permissions.yml` file
- [ ] Add workflow name and manual trigger
- [ ] Configure permissions (contents: read, issues: write)
- [ ] Add checkout step
- [ ] Add test issue creation step
- [ ] Commit and push workflow file
- [ ] Navigate to Actions tab on GitHub
- [ ] Manually trigger the workflow
- [ ] Verify workflow runs successfully
- [ ] Verify test issue was created
- [ ] Delete test issue
- [ ] Document the results

**If Test Fails:**
- [ ] Check error messages
- [ ] Review permissions settings
- [ ] Adjust settings and retry
- [ ] Document the fix

Create a minimal test workflow to verify permissions:

Create `.github/workflows/test-permissions.yml`:
```yaml
name: Test Permissions

on:
  workflow_dispatch:  # Manual trigger for testing

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Test issue creation
        run: |
          gh issue create \
            --title "Test: Permissions Check" \
            --body "Testing GitHub Actions permissions configuration. This issue can be closed immediately." \
            --label "infrastructure"
        env:
          GH_TOKEN: ${{ github.token }}
```

**Test:**
1. Commit and push this workflow
2. Go to Actions tab
3. Manually trigger the workflow
4. Verify it can create an issue
5. Delete the test issue
6. Document the results

**If it fails:**
- Check error messages
- Review permissions settings
- Adjust and retry

### Step 5: Document Permissions Model

**Time Estimate:** 45 minutes

**Permissions Documentation Checklist:**
- [ ] Document how GITHUB_TOKEN is automatically created
- [ ] Document token lifetime (job duration)
- [ ] Document repository-wide vs per-workflow permissions
- [ ] Document permission restriction capabilities
- [ ] Document security best practices
- [ ] Create list of key concepts
- [ ] Document minimum required permissions principle
- [ ] Add examples of explicit permission specifications

Document how GitHub Actions permissions work for LinkRadar:

**Key Concepts:**
- GITHUB_TOKEN is automatically created for each workflow
- Token has limited lifetime (job duration)
- Permissions can be set repository-wide or per-workflow
- Can always be more restrictive in workflow, never more permissive

**Security Best Practices:**
- Grant minimum required permissions
- Specify permissions in workflow files explicitly
- Don't use personal access tokens unless necessary
- Review third-party actions before using

### Step 6: Create Setup Script (If Possible)

**Time Estimate:** 45 minutes

**Script Research:**
- [ ] Research which Actions settings are scriptable via API
- [ ] Identify which settings are UI-only
- [ ] Document API limitations

**Script Creation (If Scriptable):**
- [ ] Create directory `project/guides/github/actions/`
- [ ] Create file `setup.sh` in the directory
- [ ] Add script header and prerequisites
- [ ] Add repository variable configuration
- [ ] Add API calls for scriptable settings
- [ ] Add clear notes about manual steps required
- [ ] Add instructions for UI-only settings
- [ ] Make script executable: `chmod +x setup.sh`

**If Not Fully Scriptable:**
- [ ] Create script with partial automation
- [ ] Document manual steps clearly
- [ ] Include verification checklist

Some Actions settings are configurable via API, others are UI-only.

Research and create `project/guides/github/actions/setup.sh` if scriptable:

```bash
#!/bin/bash
# GitHub Actions Setup Script
# Configures Actions permissions for LinkRadar workflows
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Admin access to repository
#
# Note: Some Actions settings are UI-only and cannot be scripted.
#       This script configures what's possible via API.
#
# Usage:
#   ./setup.sh [owner/repo]

set -e

REPO="${1:-username/link-radar}"

echo "Configuring GitHub Actions for $REPO..."
echo ""
echo "⚠️  Note: Some Actions settings must be configured manually via GitHub UI:"
echo "   - Actions permissions (allow all actions)"
echo "   - Fork pull request workflow settings"
echo ""
echo "This script will configure what's possible via API."
echo ""

# Configure default workflow permissions
# Note: This may require API endpoint that might not exist
# Document manual steps if API unavailable

echo "✅ Actions configuration partially complete!"
echo ""
echo "Manual steps required:"
echo "1. Go to https://github.com/$REPO/settings/actions"
echo "2. Set 'Actions permissions' to 'Allow all actions and reusable workflows'"
echo "3. Set 'Workflow permissions' to 'Read and write permissions'"
echo "4. Check 'Allow GitHub Actions to create and approve pull requests'"
echo "5. Verify fork PR workflow settings"
echo ""
echo "See guide.md for detailed instructions."
```

**If full automation isn't possible**, document manual steps clearly.

### Step 7: Create Comprehensive Guide

**Time Estimate:** 90 minutes

**Guide Creation Checklist:**
- [ ] Create directory `project/guides/github/actions/` (if not exists)
- [ ] Create file `guide.md` in the directory
- [ ] Write Overview section
- [ ] Write GitHub Actions Architecture section
- [ ] Write Permissions Explained section for each setting
- [ ] Write Manual Setup section with step-by-step
- [ ] Write Automated Setup section (or note limitations)
- [ ] Write What Phase 2/3 Workflows Need section
- [ ] Create Permission Scopes Reference table
- [ ] Write Security Best Practices section
- [ ] Write Testing Actions Permissions section
- [ ] Write Common Issues section with troubleshooting
- [ ] Write For Future Projects section
- [ ] Write Preparing for Phase 2 & 3 section
- [ ] Add References section
- [ ] Proofread and refine guide

Create `project/guides/github/actions/guide.md`:

**Guide Structure:**

```markdown
# GitHub Actions Setup Guide

## Overview

Why Actions permissions matter and what they enable.

## GitHub Actions Architecture

### How Actions Work
- Workflows, jobs, steps
- Triggers and events
- GITHUB_TOKEN explained
- Permission scopes

### Security Model
- Principle of least privilege
- Token lifetime and scope
- Repository vs workflow permissions
- Third-party action considerations

## Permissions Explained

### Actions Permissions
**What:** Which actions are allowed to run
**Options:**
- Allow all actions
- Allow local and specific actions
- Allow specific actions only

**Recommendation:** Allow all (can restrict later)

### Workflow Permissions
**What:** Default permissions for GITHUB_TOKEN
**Options:**
- Read repository contents (default)
- Read and write permissions

**Recommendation:** Read and write (required for Phase 2/3)

### Allow PR Creation
**What:** Can workflows create/approve PRs
**Why:** Useful for automated dependency updates (future)

**Recommendation:** Enable

### Fork PR Workflows
**What:** Run workflows on PRs from forks
**Security:** Require approval for first-time contributors

**Recommendation:** Require approval (if public repo)

## Manual Setup

### Step-by-Step Instructions

1. Navigate to Settings → Actions → General
2. Configure Actions permissions...
3. Set Workflow permissions...
4. Enable PR creation...
5. Configure fork PR settings...

[Detailed walkthrough with screenshots]

### Verification

How to verify settings are correct:
- Check each setting
- Test with sample workflow
- Review any error messages

## Automated Setup

### Using the Script (Partial)

```bash
cd project/guides/github/actions
./setup.sh your-username/your-repo
```

### Manual Steps Still Required

API limitations require some manual configuration.
See script output for specific steps.

## What Phase 2/3 Workflows Need

### Phase 2: CI Validation

Workflows that validate PRs:
- **Conventional Commits** - Check commit message format
- **Required Labels** - Verify type + area labels present
- **YAML/Markdown Lint** - Validate file syntax

**Permissions needed:**
- `contents: read` - Read code for linting
- `pull-requests: write` - Comment validation results
- `statuses: write` - Update PR status checks

### Phase 3: Deployment Triggers

Workflows that track deployments:
- **Merge to Main** - Create staging deployment issue
- **Tag Push** - Create production deployment issue

**Permissions needed:**
- `contents: read` - Read commit/tag information
- `issues: write` - Create deployment tracking issues

## Permission Scopes Reference

| Scope | Read | Write | Why |
|-------|------|-------|-----|
| `contents` | ✅ | ❌ | Read code, files |
| `pull-requests` | ✅ | ✅ | Comment on PRs |
| `issues` | ✅ | ✅ | Create/update issues |
| `statuses` | ✅ | ✅ | Update status checks |
| `checks` | ✅ | ✅ | Create check runs |

## Security Best Practices

### Least Privilege
- Specify permissions explicitly in workflows
- Grant only what's needed per job
- Review third-party actions before use

### Token Safety
- Never log or expose GITHUB_TOKEN
- Don't store token in variables unnecessarily
- Token expires after job completes

### Third-Party Actions
- Use official actions when possible
- Pin actions to specific commits (not tags)
- Review action source code
- Use actions with high star counts/usage

## Testing Actions Permissions

### Test Workflow

Sample workflow to verify permissions work:
[Include the test-permissions.yml example]

### Running the Test
1. Commit test workflow
2. Manually trigger
3. Verify issue creation succeeds
4. Clean up test issue

### Troubleshooting Failed Tests
- Check error messages
- Review permissions settings
- Verify token scopes
- Check repository settings

## Common Issues

### Workflow Can't Create Issues
**Error:** "Resource not accessible by integration"
**Fix:** Enable write permissions for workflows

### Status Checks Not Updating
**Error:** No error, but checks don't appear
**Fix:** Verify `statuses: write` permission in workflow

### Third-Party Action Fails
**Error:** Various
**Fix:** Check action's required permissions

## For Future Projects

### Lifting to New Repos
1. Follow manual setup steps
2. Run setup script (partial)
3. Test with sample workflow
4. Adjust for repo-specific needs

### Team Scaling
- Review who can modify workflows
- Audit third-party action usage
- Enable branch protection for workflows
- Consider required reviews for workflow changes

## Preparing for Phase 2 & 3

### What's Next

After this setup:
- ✅ Actions enabled and configured
- ✅ Permissions grant workflows necessary access
- ⏭️ Ready to create Phase 2 validation workflows
- ⏭️ Ready to create Phase 3 deployment triggers

### Phase 2 Workflows Will Add
- `.github/workflows/conventional-commits.yml`
- `.github/workflows/required-labels.yml`
- `.github/workflows/lint.yml`

### Phase 3 Workflows Will Add
- `.github/workflows/deploy-staging-placeholder.yml`
- `.github/workflows/deploy-production-placeholder.yml`

## References

- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GITHUB_TOKEN Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
```

## Deliverables

- [ ] GitHub Actions enabled in repository
- [ ] Workflow permissions set to read/write
- [ ] PR creation allowed for workflows
- [ ] `project/guides/github/actions/guide.md` - Complete documentation
- [ ] `project/guides/github/actions/setup.sh` - Script (if fully scriptable)
- [ ] Test workflow created, run, and verified
- [ ] Superthread card #132 moved to "Done"

## Success Criteria

- ✅ Actions enabled and accessible
- ✅ Workflows can read repository contents
- ✅ Workflows can create issues and comments
- ✅ Workflows can update status checks
- ✅ Test workflow successfully ran
- ✅ Guide documents all settings
- ✅ Ready for Phase 2/3 workflow creation

## Time Estimate

**Total:** ~4 hours

## Next Steps

After completing this plan:
1. Move Superthread card #132 to "Done"
2. Move LR002 feature card #95 to "Distributed" status
3. All 5 Phase 1 plans are now complete
4. Foundation ready for Phase 2 (CI Validation Workflows)

## Notes

- Some Actions settings may be UI-only (not scriptable)
- Document both automated and manual paths
- The test workflow helps verify everything works
- Permissions can always be tightened in specific workflows
- Phase 2 will add actual CI validation workflows
- Phase 3 will add deployment trigger placeholders
- This completes the Phase 1 foundation work

