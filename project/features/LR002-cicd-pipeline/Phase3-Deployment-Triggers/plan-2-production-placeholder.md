# Plan 2: Production Deployment Placeholder

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** TBD  
**Status:** Ready to Execute (after Plan 1)

## Goal

Create a GitHub Actions workflow that triggers when a version tag is pushed (e.g., `v1.0.0`) and creates a GitHub issue representing a production deployment. This proves the tag-based deployment trigger works and establishes the pattern for production releases.

## Why This Matters

Production deployment triggers:
- **Explicit releases** - Deployments tied to version tags
- **Semantic versioning** - Tags follow semver (v1.2.3)
- **Audit trail** - Issues track all production releases
- **Rollback reference** - Know which versions were deployed when
- **Future activation** - Easy to convert to real deployments

This creates the **production release workflow** without needing infrastructure.

## Trigger Event

**When:** Git tag matching `v*.*.*` is pushed

**How it happens:**
1. Developer creates a release tag: `git tag v1.0.0`
2. Developer pushes tag: `git push origin v1.0.0`
3. Workflow triggers automatically
4. GitHub issue created with release metadata

**Example tags:**
- `v0.1.0` - Initial beta release
- `v1.0.0` - First stable release
- `v1.2.3` - Minor update with patch

## What You'll Create

### 1. GitHub Actions Workflow
**Location:** `.github/workflows/deploy-production-placeholder.yml`

**Triggers:**
- `push` of tags matching `v*.*.*` pattern

**Actions:**
- Extract tag and release metadata
- Create GitHub issue with production deployment details
- Label issue with `deployment: production`
- Include version, commit, changelog summary

### 2. GitHub Label
**Create:** `deployment: production`
- **Color:** `#DC143C` (crimson red)
- **Description:** Production deployment tracking

### 3. Documentation
**Location:** Release and deployment guides

**Document:**
- How to create release tags
- Semantic versioning conventions
- Production deployment process
- How to activate real deployments

## Implementation Steps

### Step 1: Create the Deployment Label

**Time Estimate:** 5 minutes

```bash
gh label create "deployment: production" \
  --description "Production deployment tracking" \
  --color DC143C
```

Or create via GitHub UI.

### Step 2: Create the Workflow

**Time Estimate:** 75 minutes

Create `.github/workflows/deploy-production-placeholder.yml`:

```yaml
name: Deploy to Production (Placeholder)

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  create-production-deployment-issue:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get tag information
        id: tag
        run: |
          TAG_NAME=${GITHUB_REF#refs/tags/}
          echo "tag_name=$TAG_NAME" >> $GITHUB_OUTPUT
          
          # Get tag message if annotated tag
          TAG_MESSAGE=$(git tag -l --format='%(contents)' $TAG_NAME)
          echo "tag_message=$TAG_MESSAGE" >> $GITHUB_OUTPUT
          
          # Get tagged commit
          COMMIT_SHA=$(git rev-list -n 1 $TAG_NAME)
          echo "commit_sha=$COMMIT_SHA" >> $GITHUB_OUTPUT
      
      - name: Get changelog since last tag
        id: changelog
        run: |
          # Get previous tag
          PREVIOUS_TAG=$(git tag --sort=-version:refname | grep -A1 ${{ steps.tag.outputs.tag_name }} | tail -1)
          
          if [ -z "$PREVIOUS_TAG" ]; then
            # First tag - get all history
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" --no-merges)
          else
            # Get commits since previous tag
            CHANGELOG=$(git log $PREVIOUS_TAG..${{ steps.tag.outputs.tag_name }} --pretty=format:"- %s (%h)" --no-merges)
          fi
          
          # Save to file to handle multiline
          echo "$CHANGELOG" > changelog.txt
          
          # Also save previous tag for reference
          echo "previous_tag=$PREVIOUS_TAG" >> $GITHUB_OUTPUT
      
      - name: Create production deployment issue
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const tagName = '${{ steps.tag.outputs.tag_name }}';
            const commitSha = '${{ steps.tag.outputs.commit_sha }}'.substring(0, 7);
            const fullSha = '${{ steps.tag.outputs.commit_sha }}';
            const tagMessage = `${{ steps.tag.outputs.tag_message }}`;
            const previousTag = '${{ steps.changelog.outputs.previous_tag }}';
            const timestamp = new Date().toISOString();
            const changelog = fs.readFileSync('changelog.txt', 'utf8');
            
            const issueBody = `## 🚀 Production Release Ready
            
            **Release Version:** ${tagName}  
            **Deployment Type:** Placeholder (Issue Creation Only)
            
            ### Release Metadata
            
            | Field | Value |
            |-------|-------|
            | **Version Tag** | \`${tagName}\` |
            | **Commit SHA** | \`${commitSha}\` ([full](https://github.com/${context.repo.owner}/${context.repo.repo}/commit/${fullSha})) |
            | **Tagged At** | ${timestamp} |
            | **Previous Version** | ${previousTag || 'N/A (first release)'} |
            
            ${tagMessage ? `### Tag Message\n\n${tagMessage}\n` : ''}
            
            ### Changes Since Last Release
            
            ${changelog || 'No commits found (check manually)'}
            
            ### What Would Happen (Real Deployment)
            
            When real production deployment is enabled:
            
            1. **Verify tag format:**
               - Must match semver: \`vMAJOR.MINOR.PATCH\`
               - Tag must be on master branch
            
            2. **Build Docker images:**
               - \`backend:${tagName}\`
               - \`backend:sha-${commitSha}\`
               - \`backend:latest\`
            
            3. **Push to container registry:**
               - Images tagged with version and SHA
               - Extract and store image digests
            
            4. **Validate images:**
               - Run smoke tests against images
               - Verify health endpoints
            
            5. **Deploy to production:**
               - Use image digests (not tags) for reproducibility
               - Apply database migrations with backup
               - Monitor deployment health
               - Gradual rollout if configured
            
            6. **Verify deployment:**
               - Run smoke tests
               - Check health endpoints
               - Monitor error rates
            
            7. **Update this issue:**
               - Deployment status (success/failure)
               - Deployed image digests
               - Rollback instructions if needed
            
            ### Current Status
            
            ✅ Tag trigger mechanism verified  
            🔷 Placeholder only - no actual deployment  
            ⏭️  Real deployment automation comes in future feature
            
            ### Next Steps for Real Deployment
            
            To activate production deployments:
            1. Implement staging deployment first
            2. Verify staging automation stable
            3. Replace this placeholder with real deployment steps
            4. Add production health monitoring
            5. Implement rollback procedures
            
            See \`docs/deployment-activation.md\` for full production checklist.
            
            ---
            
            *This issue was created automatically by the production deployment trigger workflow. It demonstrates that tag push events are properly captured and can trigger automation.*`;
            
            const issue = await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[Production] Release ${tagName} - ${commitSha}`,
              body: issueBody,
              labels: ['deployment: production']
            });
            
            console.log(`Created production deployment issue: ${issue.data.html_url}`);
            
            core.setOutput('issue_url', issue.data.html_url);
            core.setOutput('issue_number', issue.data.number);
      
      - name: Summary
        run: |
          echo "🚀 Production deployment placeholder created"
          echo "Issue: ${{ steps.create.outputs.issue_url }}"
```

### Step 3: Document Release Process

**Time Estimate:** 60 minutes

**Create `project/guides/deployment/release-process.md`:**

```markdown
# Release Process

## Overview

This guide documents how to create releases for LinkRadar using Git tags and the automated production deployment trigger.

## Semantic Versioning

We follow [Semantic Versioning](https://semver.org/): `vMAJOR.MINOR.PATCH`

**Version format:** `vX.Y.Z`
- **MAJOR** - Incompatible API changes
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (backward compatible)

**Examples:**
- `v0.1.0` - Initial development release
- `v1.0.0` - First stable release
- `v1.1.0` - Added features to stable release
- `v1.1.1` - Bug fix for v1.1.0

## Creating a Release

### Prerequisites

- All changes merged to master
- All tests passing
- Changelog reviewed
- Ready to deploy to production

### Steps

1. **Pull latest master**
   ```bash
   git checkout master
   git pull origin master
   ```

2. **Create annotated tag**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release

   - Feature 1 implemented
   - Feature 2 implemented
   - Bug fixes for issue #123"
   ```

3. **Push tag to GitHub**
   ```bash
   git push origin v1.0.0
   ```

4. **Verify workflow triggered**
   - Go to Actions tab
   - Check "Deploy to Production (Placeholder)" workflow ran
   - Verify issue was created

5. **Review deployment issue**
   - Check all metadata is correct
   - Review changelog
   - Close issue after verification

## Tag Naming Conventions

**Format:** `v{major}.{minor}.{patch}`

**Rules:**
- Always prefix with `v`
- Use semantic versioning
- Create from master branch only
- Use annotated tags (not lightweight)
- Include release notes in tag message

**Good:**
- `v0.1.0` - First beta
- `v1.0.0` - First stable
- `v1.2.3` - Version one, minor two, patch three

**Bad:**
- `1.0.0` - Missing `v` prefix
- `v1.0` - Missing patch version
- `release-1.0.0` - Wrong prefix

## Annotated vs Lightweight Tags

**Use annotated tags:**
```bash
git tag -a v1.0.0 -m "Release message"
```

**Not lightweight tags:**
```bash
git tag v1.0.0  # Don't do this
```

**Why annotated?**
- Includes tagger name and date
- Can include release notes
- More formal and complete
- Required by some deployment systems

## Current Workflow

**What happens when you push a tag:**

1. ✅ Workflow triggers on tag push
2. ✅ Issue created with release metadata
3. ✅ Issue labeled `deployment: production`
4. 🔷 No actual deployment (placeholder)

**Future workflow:**

1. Workflow triggers on tag push
2. Docker images built and tagged
3. Images pushed to registry
4. Deployed to production
5. Health checks run
6. Issue updated with deployment status

## Managing Releases

**List all releases:**
```bash
git tag -l
```

**Delete a tag (before pushing):**
```bash
git tag -d v1.0.0
```

**Delete a remote tag (careful!):**
```bash
git push origin :refs/tags/v1.0.0
```

**View tag details:**
```bash
git show v1.0.0
```

## Best Practices

**Before tagging:**
- Review all changes since last tag
- Run all tests locally
- Update changelog/release notes
- Verify master is in deployable state

**Tag message format:**
```
Release vX.Y.Z: Brief description

- Major change 1
- Major change 2
- Bug fix for issue #123

Breaking changes:
- List any breaking changes

Migration notes:
- Any migration steps needed
```

**After tagging:**
- Verify workflow ran successfully
- Review deployment issue
- Monitor for any issues
- Create GitHub release if desired

## Troubleshooting

**Tag pushed but no workflow:**
- Check tag matches pattern `v*.*.*`
- Verify workflow file is on master
- Check Actions tab for any errors

**Wrong tag pushed:**
- Delete tag: `git push origin :refs/tags/vX.Y.Z`
- Create correct tag
- Push again

**Need to re-deploy same version:**
- Delete and recreate tag
- Or create new patch version (v1.0.1)
```

### Step 4: Test the Workflow

**Time Estimate:** 45 minutes

**Test 1: Create a test release**
```bash
git checkout master
git pull origin master
git tag -a v0.1.0 -m "Test release

Testing production deployment trigger workflow."
git push origin v0.1.0
```

**Verify:**
- [ ] Workflow triggers
- [ ] Issue is created
- [ ] Issue has `deployment: production` label
- [ ] All metadata is correct
- [ ] Changelog is included
- [ ] Previous tag reference is correct (or N/A for first)

**Test 2: Create a second release**
```bash
git tag -a v0.1.1 -m "Second test release"
git push origin v0.1.1
```

**Verify:**
- [ ] Issue shows changelog between v0.1.0 and v0.1.1
- [ ] Previous tag reference shows v0.1.0

**Test 3: Delete test tags**
```bash
git push origin :refs/tags/v0.1.0
git push origin :refs/tags/v0.1.1
git tag -d v0.1.0 v0.1.1
```

**Close test issues** created during testing.

### Step 5: Create Activation Checklist

**Time Estimate:** 30 minutes

**Create `project/guides/deployment/activation-checklist.md`:**

```markdown
# Deployment Automation Activation Checklist

## Overview

This checklist guides you through converting placeholder workflows to real deployments.

## Prerequisites

Before activating deployment automation:

- [ ] Staging environment exists and is accessible
- [ ] Production environment exists and is accessible
- [ ] Container registry configured (Docker Hub, GitHub Packages, etc.)
- [ ] Registry credentials stored in GitHub secrets
- [ ] Database backup/restore procedures documented
- [ ] Rollback procedures tested
- [ ] Monitoring and alerting configured
- [ ] Team trained on deployment process

## Staging Deployment Activation

- [ ] Update `.github/workflows/deploy-staging-placeholder.yml`
- [ ] Add Docker build job
- [ ] Add image push to registry job
- [ ] Add deployment to staging job
- [ ] Add health check verification
- [ ] Test with actual deployment
- [ ] Update documentation with real process
- [ ] Rename file to `deploy-staging.yml`

## Production Deployment Activation

- [ ] Staging deployment working reliably
- [ ] Production environment fully configured
- [ ] Database migration procedures tested
- [ ] Update `.github/workflows/deploy-production-placeholder.yml`
- [ ] Add Docker build job
- [ ] Add image push to registry job
- [ ] Add deployment to production job
- [ ] Add health check verification
- [ ] Add rollback procedures
- [ ] Test with controlled release
- [ ] Update documentation with real process
- [ ] Rename file to `deploy-production.yml`

## Verification

After activation:
- [ ] Staging deploys work on every merge
- [ ] Production deploys work on every tag
- [ ] Health checks pass after deployment
- [ ] Issues are updated with deployment status
- [ ] Rollback procedures work
- [ ] Team can deploy confidently

## Rollback Plan

If real deployments cause issues:
- Revert workflow to placeholder
- Document lessons learned
- Fix issues in staging
- Re-activate when stable
```

## Deliverables

- [ ] `.github/workflows/deploy-production-placeholder.yml` - Production trigger workflow
- [ ] `deployment: production` label created
- [ ] `project/guides/deployment/release-process.md` - Release documentation
- [ ] `project/guides/deployment/activation-checklist.md` - Activation guide
- [ ] Test issues demonstrating tag triggers
- [ ] Screenshots showing issue creation

## Success Criteria

- ✅ Workflow triggers automatically on version tag push
- ✅ Issue is created with complete release metadata
- ✅ Issue includes changelog since last version
- ✅ Issue clearly explains it's a placeholder
- ✅ Issue includes activation instructions
- ✅ Tag patterns work correctly (v*.*.*)
- ✅ Metadata is accurate and useful
- ✅ Release process is documented

## Time Estimate

**Total:** ~3.5 hours

## Next Steps

After completing this plan:
1. Test with real version tags
2. Phase 3 complete!
3. LR002 CI/CD Pipeline feature COMPLETE! 🎉
4. Ready to move to real deployments when infrastructure is stable

## Notes

- Use annotated tags, not lightweight tags
- Tag from master branch only
- Follow semantic versioning
- Changelog extraction requires git history
- Issues serve as deployment audit log
- Test tags can be deleted without issues
- Real deployments will update issues instead of just creating them

## References

- [Semantic Versioning](https://semver.org/)
- [Git Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
- [GitHub Actions: Tag Filters](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#running-your-workflow-only-when-a-push-affects-specific-files)
- [Generating Changelogs](https://keepachangelog.com/)

