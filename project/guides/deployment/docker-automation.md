# Docker Build Automation

## Overview

Automated Docker image builds and pushes to GitHub Container Registry (GHCR) via GitHub Actions. Every merge to `master` and every version tag creates production-ready Docker images with semantic tagging.

## How It Works

### Workflow Trigger

The `docker-build-push.yml` workflow runs on:

1. **Push to `master`** - Creates images for staging deployment
2. **Version tags** (`v*.*.*`) - Creates images for production deployment
3. **Manual trigger** - On-demand builds via GitHub Actions UI

### Image Tagging Strategy

The workflow creates **multiple tags** for each build to support different use cases:

#### Master Branch Push

```
ghcr.io/steveclarke/lr-backend:master          (semantic - latest staging)
ghcr.io/steveclarke/lr-backend:sha-abc123      (immutable - specific commit)
```

#### Version Tag Push

```
ghcr.io/steveclarke/lr-backend:v1.0.0          (semantic - version)
ghcr.io/steveclarke/lr-backend:latest          (semantic - latest release)
ghcr.io/steveclarke/lr-backend:sha-abc123      (immutable - specific commit)
```

### Why Multiple Tags?

- **SHA tags** (`sha-abc123`) - Immutable, for reproducible deployments
- **Branch tags** (`master`) - Semantic, always points to latest staging
- **Version tags** (`v1.0.0`) - Semantic, for production releases
- **latest** - Convenience tag for production

## Build Process

### 1. Metadata Extraction

The workflow extracts:
- **Version** from `backend/VERSION` file
- **Commit SHA** for immutable tagging
- **Trigger type** (branch or tag) to determine tags

### 2. Docker Build

- **Platform:** `linux/amd64` (production servers)
- **Build context:** `backend/` directory
- **Buildx:** Uses Docker Buildx for multi-platform support
- **Cache:** GitHub Actions cache for faster builds

### 3. Push to Registry

Images pushed to: `ghcr.io/steveclarke/lr-backend`

All tags pushed simultaneously in a single operation.

### 4. Build Metadata Capture

The workflow outputs:
- `version` - Version from VERSION file
- `sha_tag` - Immutable SHA-based tag
- `image_digest` - Image digest (for reproducibility)
- `image_ref` - Full image reference

### 5. Deployment Issue Update

If staging or production placeholder issues exist for the commit:
- Automatically adds a comment with image details
- Includes pull commands
- Shows digest for immutable deployment

## Using Built Images

### Pull Latest Staging Image

```bash
docker pull ghcr.io/steveclarke/lr-backend:master
```

### Pull Latest Production Image

```bash
docker pull ghcr.io/steveclarke/lr-backend:latest
```

### Pull Specific Commit (Immutable)

```bash
docker pull ghcr.io/steveclarke/lr-backend:sha-abc123
```

### Pull by Digest (Most Immutable)

```bash
docker pull ghcr.io/steveclarke/lr-backend@sha256:abc123...
```

## Integration with Deployment

### Current State (Placeholder Mode)

The Docker build workflow:
1. ✅ Builds images automatically
2. ✅ Pushes to GHCR with semantic tags
3. ✅ Updates deployment placeholder issues
4. ⏳ Deployment still manual (via `deploy/bin/deploy`)

### Future State (Full Automation)

When deployment placeholders are replaced:
1. ✅ Builds images automatically
2. ✅ Pushes to GHCR
3. ✅ Triggers automated deployment
4. ✅ Deploys to staging/production
5. ✅ Runs smoke tests
6. ✅ Notifies team

## Local Build vs CI Build

### Local Build (Development)

```bash
cd backend
bin/docker-build --local    # Fast, local platform
bin/docker-push             # Push to GHCR
```

**When to use:**
- Testing Docker setup changes
- Debugging build issues
- Emergency hotfix deployment

### CI Build (Production)

Automatic on merge/tag push.

**Advantages:**
- Consistent build environment
- Proper platform targeting
- Build cache optimization
- Automated tagging
- Integration with deployment

## Versioning

### VERSION File

The `backend/VERSION` file controls the version number:

```
0.1.1
```

**Update process:**
1. Edit `backend/VERSION` file
2. Commit change
3. Merge to master or create tag
4. CI builds with new version

### Version Tag Correlation

For production releases:
- Git tag: `v1.0.0`
- VERSION file: `1.0.0`
- Docker tag: `ghcr.io/steveclarke/lr-backend:v1.0.0`

**Best practice:** Keep these in sync!

## Build Outputs

### GitHub Actions Summary

Each build creates a summary with:
- Version and SHA tag
- Image digest
- All tags pushed
- Pull command
- Link to GHCR

### Deployment Issue Comment

For staging/production builds, issues receive:
- Image reference and tags
- Pull commands
- Digest for immutable deployment
- "Ready for deployment" notice

## Troubleshooting

### Build Fails

**Check:**
1. `backend/VERSION` file exists and is valid
2. `backend/Dockerfile` is correct
3. All dependencies in `Gemfile` are resolvable
4. Build context (backend/) has all needed files

### Push Fails

**Check:**
1. GitHub Actions has `packages: write` permission (it does)
2. Image name matches `ghcr.io/steveclarke/lr-backend`
3. GHCR is accessible (check GitHub status)

### Tags Not Created

**Check:**
1. Workflow triggered correctly (master push or tag push)
2. Metadata extraction succeeded
3. Build step completed successfully

### Wrong Platform

Images are built for `linux/amd64` by default.

**To change:**
Edit `PLATFORMS` in `.github/workflows/docker-build-push.yml`

## Manual Workflow Dispatch

Trigger a build manually:

1. Go to **Actions** tab
2. Select **Build and Push Docker Images**
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow**

## Monitoring

### View Build Logs

1. Go to **Actions** tab
2. Select **Build and Push Docker Images** workflow
3. Click on specific run
4. View logs for each step

### View Images

GitHub Container Registry:
https://github.com/steveclarke/link-radar/pkgs/container/lr-backend

### Check Image Size

```bash
docker image inspect ghcr.io/steveclarke/lr-backend:latest --format='{{.Size}}'
```

## Security

### Image Scanning

**Currently:** Not implemented

**Future:** Add Trivy or similar scanner to workflow

### Secrets

**GITHUB_TOKEN:** Automatically provided by GitHub Actions
- Used for GHCR authentication
- Scoped to repository packages
- No manual setup needed

## Performance

### Build Time

Typical build: **3-5 minutes**

Factors affecting speed:
- Gem installation
- Bootsnap precompilation
- Platform targeting
- Cache hits

### Cache Strategy

Uses GitHub Actions cache:
- **cache-from:** Pulls previous build layers
- **cache-to:** Stores current build layers
- **mode=max:** Caches all layers for speed

## Related Documentation

- [Staging Trigger](./staging-trigger.md) - Automated staging deployments
- [Release Process](./release-process.md) - Creating production releases
- [Activation Checklist](./activation-checklist.md) - Converting placeholders to real deployment

## Next Steps

After images are building automatically:

1. ✅ Test staging deployment with new images
2. ⏳ Replace placeholder workflows with real deployment
3. ⏳ Add smoke tests after deployment
4. ⏳ Add Slack/email notifications
5. ⏳ Add image vulnerability scanning

