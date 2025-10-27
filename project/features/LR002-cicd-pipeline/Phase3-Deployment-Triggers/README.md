# Phase 3: Deployment Trigger Placeholders

**Status:** Ready to Execute  
**Prerequisites:** Phase 2 CI Validation complete ✅

## Overview

Phase 3 creates deployment trigger workflows that respond to deployable events (merges to master, version tags) and create GitHub issues as placeholders for actual deployments. This proves the trigger mechanisms work without requiring infrastructure.

## Goals

Create two GitHub Actions workflows that:
1. Trigger on merge to `master` → Create staging deployment issue
2. Trigger on version tag push → Create production deployment issue

These issues demonstrate that:
- ✅ Trigger mechanisms work correctly
- ✅ Metadata is captured properly
- ✅ Deployment pattern is established
- ✅ Easy to activate real deployments later

## Why Placeholders?

**The Problem:**
- LR001 infrastructure isn't complete yet
- No staging/production environments exist
- Don't want to block CI/CD work waiting for infrastructure

**The Solution:**
- Create the trigger workflows NOW
- Use GitHub issue creation as placeholder
- Capture all the metadata real deployments will need
- When infrastructure is ready, replace issue creation with real deployment

**Benefits:**
- Validates trigger mechanisms work
- Establishes deployment pattern
- Creates deployment audit trail
- Enables planning without infrastructure
- Easy activation path when ready

## Phase 3 Plans

### Plan 1: Staging Deployment Placeholder
**Time:** ~3 hours  
**Deliverable:** `.github/workflows/deploy-staging-placeholder.yml`

**Trigger:** Push to `master` branch (after PR merge)

**Creates issue with:**
- Commit SHA
- Commit message
- PR number
- Author
- Timestamp
- What real deployment would do
- Activation instructions

**Label:** `deployment: staging`

### Plan 2: Production Deployment Placeholder
**Time:** ~3.5 hours  
**Deliverable:** `.github/workflows/deploy-production-placeholder.yml`

**Trigger:** Push of version tags (`v*.*.*`)

**Creates issue with:**
- Version tag
- Commit SHA
- Tag message
- Changelog since last version
- Previous version reference
- What real deployment would do
- Activation instructions

**Label:** `deployment: production`

## Execution Order

**Must be done in sequence:**

1. ✅ **Plan 1** → Staging placeholder (tests merge trigger)
2. ✅ **Plan 2** → Production placeholder (tests tag trigger)

**Why sequential?**
- Staging is simpler (just merge)
- Production builds on staging pattern
- Want to verify merge triggers before tag triggers

## Deployment Trigger Events

### Staging: Merge to Master

**What triggers it:**
```yaml
on:
  push:
    branches:
      - master
```

**When it runs:**
- After every PR is merged (squash merge creates push)
- After direct push to master (if bypass used)

**Frequency:** Every merge (could be multiple times per day)

### Production: Version Tag Push

**What triggers it:**
```yaml
on:
  push:
    tags:
      - 'v*.*.*'
```

**When it runs:**
- When you explicitly push a version tag
- Example: `git push origin v1.0.0`

**Frequency:** Controlled by you (releases are explicit)

## Issue-Based Deployment Tracking

**Why use issues?**
- ✅ Built-in GitHub feature (no extra tools)
- ✅ Supports comments and discussion
- ✅ Can be labeled and filtered
- ✅ Creates audit trail
- ✅ Easy to search deployment history

**Finding deployment issues:**
```bash
# List all staging deployments
gh issue list --label "deployment: staging"

# List all production deployments
gh issue list --label "deployment: production"

# Find specific version
gh issue list --search "v1.0.0 in:title"
```

## Metadata Captured

### Staging Deployment Issues Include:

- Commit SHA (short and full)
- Commit message
- Author
- Timestamp
- Source PR number
- What real deployment would do
- Activation instructions

### Production Deployment Issues Include:

All of staging metadata, plus:
- Version tag
- Tag message (release notes)
- Changelog since previous version
- Previous version reference
- Semantic versioning info

## Future Activation

### When Infrastructure is Ready

**Staging deployment activation:**
1. Staging environment exists
2. Registry configured
3. Replace issue creation with:
   - Docker build
   - Image push
   - Deploy to staging
   - Health checks
4. Update issue with deployment results

**Production deployment activation:**
1. Staging automation stable
2. Production environment ready
3. Replace issue creation with:
   - Docker build (versioned images)
   - Image push with digests
   - Deploy to production
   - Health checks
   - Rollback capability
4. Update issue with deployment results

See `activation-checklist.md` for complete activation steps.

## Success Criteria

After Phase 3 completion:

- ✅ Merge to master creates staging deployment issue
- ✅ Tag push creates production deployment issue
- ✅ Issues contain all necessary metadata
- ✅ Issues explain they're placeholders
- ✅ Activation path is documented
- ✅ Release process is documented
- ✅ Team understands how to create releases

## Time Estimate

**Total for Phase 3:** ~6.5 hours (1 day)

- Plan 1: ~3 hours
- Plan 2: ~3.5 hours

## What Gets Tracked

After Phase 3, you'll have GitHub issues for:

| Event | Label | Trigger | Frequency |
|-------|-------|---------|-----------|
| Merge to master | `deployment: staging` | Automatic | Every merge |
| Tag push `v*.*.*` | `deployment: production` | Manual | On release |

**Example issue history:**
- Issue #15: [Staging] Deploy abc1234 - feat(backend): add auth
- Issue #16: [Staging] Deploy def5678 - fix(extension): popup issue
- Issue #17: [Production] Release v1.0.0 - abc1234
- Issue #18: [Staging] Deploy ghi9012 - chore: update deps
- Issue #19: [Production] Release v1.0.1 - ghi9012

## After Phase 3

**LR002 is COMPLETE!** You'll have:

✅ **Phase 1:** Foundation (labels, templates, workflow docs, protections, Actions setup)  
✅ **Phase 2:** CI Validation (commit format, labels, linting)  
✅ **Phase 3:** Deployment Triggers (staging + production placeholders)

**Result:** Full CI/CD pipeline without needing infrastructure!

**Future work:**
- Convert placeholders to real deployments
- Add smoke tests
- Add health monitoring
- Add rollback automation

## References

- [GitHub Actions: Push Events](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#push)
- [Git Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
- [Semantic Versioning](https://semver.org/)

