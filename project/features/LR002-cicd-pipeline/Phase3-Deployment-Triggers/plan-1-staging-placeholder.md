# Plan 1: Staging Deployment Placeholder

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** TBD  
**Status:** Ready to Execute (after Phase 2 complete)

## Goal

Create a GitHub Actions workflow that triggers when code is merged to `master` and creates a GitHub issue representing a staging deployment. This proves the trigger mechanism works and establishes the pattern for real deployments later, without requiring actual infrastructure.

## Why This Matters

Deployment trigger placeholders:
- **Prove triggers work** - Validates GitHub Actions responds to merge events
- **Establish pattern** - Same structure as real deployments, just different action
- **Track readiness** - Issues show what's ready for staging
- **Enable planning** - Can see deployment history via issues
- **Easy activation** - Replace issue creation with real deployment when ready

This creates the **deployment trigger framework** without needing infrastructure.

## Trigger Event

**When:** Code is merged to `master` branch

**How it happens:**
1. Developer creates PR
2. All validation checks pass (Phase 2)
3. PR is approved
4. PR is merged (squash merge)
5. Workflow triggers automatically
6. GitHub issue created with deployment metadata

## What You'll Create

### 1. GitHub Actions Workflow
**Location:** `.github/workflows/deploy-staging-placeholder.yml`

**Triggers:**
- `push` to `master` branch (happens after PR merge)

**Actions:**
- Extract merge metadata (commit SHA, PR number, author, message)
- Create GitHub issue with deployment details
- Label issue with `deployment: staging` (create this label)
- Include all metadata needed for real deployment

### 2. GitHub Label
**Create:** `deployment: staging`
- **Color:** `#FFA500` (orange)
- **Description:** Staging deployment tracking

### 3. Documentation
**Location:** Update deployment guides

**Document:**
- How the staging trigger works
- What metadata is included
- How to activate real deployments later

## Implementation Steps

### Step 1: Create the Deployment Label

**Time Estimate:** 5 minutes

```bash
gh label create "deployment: staging" \
  --description "Staging deployment tracking" \
  --color FFA500
```

Or create via GitHub UI in Settings → Labels.

### Step 2: Create the Workflow

**Time Estimate:** 60 minutes

Create `.github/workflows/deploy-staging-placeholder.yml`:

```yaml
name: Deploy to Staging (Placeholder)

on:
  push:
    branches:
      - master

jobs:
  create-staging-deployment-issue:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get PR number from merge commit
        id: pr
        run: |
          # Extract PR number from merge commit message
          PR_NUMBER=$(git log -1 --pretty=%B | grep -oP '#\K\d+' || echo "")
          echo "pr_number=$PR_NUMBER" >> $GITHUB_OUTPUT
      
      - name: Create staging deployment issue
        uses: actions/github-script@v7
        with:
          script: |
            const prNumber = '${{ steps.pr.outputs.pr_number }}';
            const sha = context.sha.substring(0, 7);
            const commitMessage = context.payload.head_commit.message.split('\n')[0];
            const author = context.payload.head_commit.author.name;
            const timestamp = new Date().toISOString();
            
            const issueBody = `## 🚀 Staging Deployment Ready
            
            **Deployment Type:** Placeholder (Issue Creation Only)
            
            ### Deployment Metadata
            
            | Field | Value |
            |-------|-------|
            | **Commit SHA** | \`${sha}\` ([full](${context.payload.head_commit.url})) |
            | **Commit Message** | ${commitMessage} |
            | **Author** | ${author} |
            | **Triggered At** | ${timestamp} |
            | **Source PR** | ${prNumber ? `#${prNumber}` : 'Direct push'} |
            | **Branch** | \`master\` |
            
            ### What Would Happen (Real Deployment)
            
            When real deployment automation is enabled:
            
            1. **Build Docker images:**
               - \`backend:sha-${sha}\`
               - \`backend:master\`
            
            2. **Push to container registry:**
               - Images tagged with SHA and branch name
               - Image digests stored for reproducibility
            
            3. **Deploy to staging environment:**
               - Update staging environment with new images
               - Run database migrations if needed
               - Verify deployment health
            
            4. **Report status:**
               - Update this issue with deployment results
               - Comment on source PR if applicable
            
            ### Current Status
            
            ✅ Trigger mechanism verified  
            🔷 Placeholder only - no actual deployment  
            ⏭️  Real deployment automation comes in future feature
            
            ### Next Steps for Real Deployment
            
            To activate real deployments:
            1. Replace issue creation with deployment steps
            2. Add Docker build job
            3. Add image push to registry
            4. Add deployment to staging environment
            5. Add health checks
            
            See \`docs/deployment-automation.md\` for activation checklist.
            
            ---
            
            *This issue was created automatically by the staging deployment trigger workflow. It demonstrates that merge events are properly captured and can trigger automation.*`;
            
            const issue = await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[Staging] Deploy ${sha} - ${commitMessage}`,
              body: issueBody,
              labels: ['deployment: staging']
            });
            
            console.log(`Created staging deployment issue: ${issue.data.html_url}`);
```

**Key features:**
- Extracts all relevant metadata from the merge
- Creates detailed issue with what WOULD happen
- Labels for easy filtering
- Documents activation path for real deployments

### Step 3: Test the Workflow

**Time Estimate:** 30 minutes

**Test 1: Merge a PR**
1. Create a test PR
2. Merge it to master
3. Verify workflow triggers automatically
4. Check that issue is created
5. Verify issue has all metadata
6. Review issue formatting and clarity

**Test 2: Direct push (if bypass enabled)**
1. Push directly to master
2. Verify workflow still triggers
3. Check that PR number shows as "Direct push"

**Document:**
- [ ] Screenshots of the created issue
- [ ] Workflow run logs
- [ ] Verification that metadata is complete

### Step 4: Refine the Issue Template

**Time Estimate:** 30 minutes

**Based on testing, improve:**
- Issue title format
- Metadata completeness
- Activation instructions
- Links to relevant docs
- Formatting and readability

**Consider adding:**
- Link to commit diff
- List of files changed
- Links to related issues/PRs
- Deployment checklist for manual verification

### Step 5: Document the System

**Time Estimate:** 45 minutes

**Create `project/guides/deployment/staging-trigger.md`:**

```markdown
# Staging Deployment Trigger

## Overview

When code is merged to master, a GitHub Actions workflow automatically triggers to represent a staging deployment.

## Current Implementation: Placeholder

**What happens now:**
- Workflow triggers on merge to master
- GitHub issue is created with deployment metadata
- Issue labeled `deployment: staging`

**Purpose:**
- Proves trigger mechanism works
- Establishes metadata collection
- Documents deployment pattern
- Tracks what's ready for staging

## Trigger Mechanism

**Event:** `push` to `master` branch  
**Frequency:** Every merge (after squash)  
**Workflow:** `.github/workflows/deploy-staging-placeholder.yml`

## Issue Contents

Each deployment issue includes:

- Commit SHA (short and full)
- Commit message
- Author
- Timestamp
- Source PR number
- What would happen in real deployment
- Activation instructions

## Filtering Deployment Issues

```bash
# List all staging deployment issues
gh issue list --label "deployment: staging"

# View recent staging deployments
gh issue list --label "deployment: staging" --limit 10
```

## Future: Real Deployment Activation

To convert from placeholder to real deployment:

1. Add Docker build steps
2. Add image push to registry
3. Add deployment to staging environment
4. Update issue with deployment results
5. Add rollback capabilities

See `docs/deployment-activation.md` for full checklist.

## Maintenance

**Issue cleanup:**
- Close issues after successful deployment verification
- Keep issues open if deployment needs investigation
- Issues serve as deployment audit log
```

## Deliverables

- [ ] `.github/workflows/deploy-staging-placeholder.yml` - Staging trigger workflow
- [ ] `deployment: staging` label created
- [ ] `project/guides/deployment/staging-trigger.md` - Documentation
- [ ] Test issue demonstrating the workflow
- [ ] Screenshots showing issue creation

## Success Criteria

- ✅ Workflow triggers automatically on merge to master
- ✅ Issue is created with complete metadata
- ✅ Issue clearly explains it's a placeholder
- ✅ Issue includes activation instructions
- ✅ Metadata is accurate and useful
- ✅ Issue formatting is clear and professional

## Time Estimate

**Total:** ~3 hours

## Next Steps

After completing this plan:
1. Test with actual merges
2. Proceed to Plan 2 (Production Placeholder)
3. Phase 3 complete - LR002 done!

## Notes

- This workflow runs on merge, not on PR creation
- Issue creation is cheap - don't worry about creating many
- Issues can be closed/archived after review
- Real deployment will update the issue instead of just creating it
- Metadata collected here is exactly what real deployment needs

## References

- [GitHub Actions: Push Event](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#push)
- [GitHub Actions: Creating Issues](https://docs.github.com/en/rest/issues/issues#create-an-issue)
- [GitHub Script Action](https://github.com/actions/github-script)

