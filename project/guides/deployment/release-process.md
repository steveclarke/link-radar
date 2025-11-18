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

## References

- [Semantic Versioning](https://semver.org/)
- [Git Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
- [GitHub Actions: Tag Filters](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#running-your-workflow-only-when-a-push-affects-specific-files)

