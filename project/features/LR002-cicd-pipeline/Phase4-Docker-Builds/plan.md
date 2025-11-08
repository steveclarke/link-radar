# Phase 4: Docker Image Build & Registry Push

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Phase:** Phase 4 - Docker Image Build Automation  
**Status:** Ready to Execute (after Phase 3 complete)

## Goal

Automate Docker image builds and pushes to GitHub Container Registry (GHCR) when code is merged to `master` or version tags are pushed. This moves your existing local build process into GitHub Actions, creating the foundation for automated deployments.

## Why This Matters

Automated Docker builds:
- **Eliminate manual steps** - No more local builds and pushes
- **Semantic tagging** - Images tagged with SHA, branch, and version
- **Reproducibility** - Image digests captured for exact reproduction
- **Deployment ready** - Images available for staging/production deploys
- **Audit trail** - Every merge and tag produces a versioned artifact

This bridges the gap between **validation** (Phase 2) and **deployment** (future).

## What You'll Build

### 1. Docker Build Workflow
**Location:** `.github/workflows/build-backend.yml`

**Triggers:**
- `push` to `master` branch (after PR merge)
- `push` of tags matching `v*.*.*` (version releases)

**Outputs:**
- Docker images pushed to `ghcr.io/steveclarke/lr-backend`
- Multiple tags per build for flexibility
- Image digest for reproducibility

**Tags Applied:**

For merge to `master`:
- `sha-abc123` (specific commit)
- `master` (latest on master branch)

For version tag `v1.0.0`:
- `sha-abc123` (specific commit)
- `v1.0.0` (semantic version)
- `latest` (latest production release)

### 2. Integration with Placeholder Workflows

Update staging and production placeholder workflows to:
- Reference the built images
- Include image digest in deployment metadata
- Show that images are ready for deployment

### 3. Documentation

**Location:** `project/guides/deployment/docker-builds.md`

**Document:**
- How image building works
- Tagging strategy and semantics
- How to find and pull images
- Image digest usage for reproducibility
- Troubleshooting build failures

## Prerequisites

### GitHub Container Registry Setup

1. **Repository Settings:**
   - Ensure GitHub Actions has write permissions to packages
   - Settings → Actions → General → Workflow permissions → Read and write permissions

2. **GHCR Authentication:**
   - GitHub Actions automatically provides `GITHUB_TOKEN` with registry access
   - No additional secrets needed for GHCR push

3. **Package Visibility:**
   - After first push, configure package visibility (public/private) in package settings

### Docker Buildx

GitHub Actions runners come with Docker Buildx pre-installed, supporting:
- Multi-platform builds (if needed later)
- Build caching for faster builds
- Advanced build features

## Implementation Steps

### Step 1: Create Docker Build Workflow

**Time Estimate:** 90 minutes

Create `.github/workflows/build-backend.yml`:

```yaml
name: Build Backend Docker Image

on:
  push:
    branches:
      - master
    tags:
      - 'v*.*.*'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository_owner }}/lr-backend

jobs:
  build-and-push:
    name: Build and push Docker image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        run: |
          # Determine if this is a branch push or tag push
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            # Tag push (production release)
            VERSION=${GITHUB_REF#refs/tags/}
            echo "version=$VERSION" >> $GITHUB_OUTPUT
            echo "is_release=true" >> $GITHUB_OUTPUT
          else
            # Branch push (staging)
            BRANCH=${GITHUB_REF#refs/heads/}
            echo "branch=$BRANCH" >> $GITHUB_OUTPUT
            echo "is_release=false" >> $GITHUB_OUTPUT
          fi
          
          # Short SHA for all builds
          SHORT_SHA=${GITHUB_SHA::7}
          echo "short_sha=$SHORT_SHA" >> $GITHUB_OUTPUT

      - name: Generate Docker tags
        id: docker_tags
        run: |
          TAGS="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:sha-${{ steps.meta.outputs.short_sha }}"
          
          if [[ "${{ steps.meta.outputs.is_release }}" == "true" ]]; then
            # Release build: add version tag and latest
            TAGS="$TAGS,${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}"
            TAGS="$TAGS,${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest"
          else
            # Branch build: add branch tag
            TAGS="$TAGS,${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.branch }}"
          fi
          
          echo "tags=$TAGS" >> $GITHUB_OUTPUT

      - name: Build and push Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          file: ./backend/Dockerfile
          push: true
          tags: ${{ steps.docker_tags.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Output image details
        run: |
          echo "## 🐳 Docker Image Built Successfully" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Image Digest:** \`${{ steps.build.outputs.digest }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Tags:**" >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          echo "${{ steps.docker_tags.outputs.tags }}" | tr ',' '\n' >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Pull Command:**" >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`bash" >> $GITHUB_STEP_SUMMARY
          echo "docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:sha-${{ steps.meta.outputs.short_sha }}" >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY

      - name: Export image metadata
        id: export
        run: |
          echo "digest=${{ steps.build.outputs.digest }}" >> $GITHUB_OUTPUT
          echo "image_url=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" >> $GITHUB_OUTPUT
```

**Key Features:**
- Automatic authentication using `GITHUB_TOKEN`
- Smart tagging based on trigger type (branch vs tag)
- Build caching for faster builds (GitHub Actions cache)
- Image digest extraction for reproducibility
- Job summary with pull commands

### Step 2: Update Staging Placeholder Workflow

**Time Estimate:** 30 minutes

Modify `.github/workflows/deploy-staging-placeholder.yml` to reference built images:

Add a job dependency:

```yaml
jobs:
  build-backend:
    uses: ./.github/workflows/build-backend.yml
    
  staging-deployment-placeholder:
    needs: build-backend
    # ... rest of existing job
```

Update the issue body to include image information:

```javascript
const issueBody = `## 🚀 Staging Deployment Ready

**Deployment Type:** Placeholder (Issue Creation Only)
**Docker Image:** Built and pushed to registry

### Deployment Metadata

| Field | Value |
|-------|-------|
| **Commit SHA** | \`${metadata.shortSha}\` ([full commit](${metadata.commitUrl})) |
| **Docker Image** | \`ghcr.io/steveclarke/lr-backend:sha-${metadata.shortSha}\` |
| **Image Digest** | \`${imageDigest}\` (for reproducibility) |
| **Commit Message** | ${escapeBackticks(metadata.commitMessage)} |
...
`;
```

### Step 3: Update Production Placeholder Workflow

**Time Estimate:** 30 minutes

Similarly update `.github/workflows/deploy-production-placeholder.yml` to reference built images and include image metadata in the production deployment issue.

### Step 4: Create Documentation

**Time Estimate:** 60 minutes

Create `project/guides/deployment/docker-builds.md`:

```markdown
# Docker Image Builds

## Overview

Docker images for the LinkRadar backend are automatically built and pushed to GitHub Container Registry (GHCR) when code is merged or version tags are created.

## Registry Location

**Registry:** GitHub Container Registry (GHCR)  
**Repository:** `ghcr.io/steveclarke/lr-backend`  
**Visibility:** Private (authenticate with GitHub token to pull)

## Build Triggers

### Staging Builds (Merge to Master)

**When:** Code is merged to `master` branch  
**Workflow:** `.github/workflows/build-backend.yml`  
**Tags Applied:**
- `sha-abc123` - Specific commit (primary)
- `master` - Latest on master branch (moves with each build)

**Example:**
```bash
docker pull ghcr.io/steveclarke/lr-backend:sha-9c68c4a
docker pull ghcr.io/steveclarke/lr-backend:master  # always latest
```

### Production Builds (Version Tags)

**When:** Version tag is pushed (e.g., `v1.0.0`)  
**Workflow:** `.github/workflows/build-backend.yml`  
**Tags Applied:**
- `sha-abc123` - Specific commit (primary)
- `v1.0.0` - Semantic version (immutable)
- `latest` - Latest production release (moves with each build)

**Example:**
```bash
docker pull ghcr.io/steveclarke/lr-backend:sha-3d4f8e0
docker pull ghcr.io/steveclarke/lr-backend:v1.0.0
docker pull ghcr.io/steveclarke/lr-backend:latest
```

## Tagging Strategy

### SHA Tags (Primary)

**Format:** `sha-{7-char-sha}`  
**Purpose:** Immutable reference to exact commit  
**Usage:** Production deployments should use SHA tags for reproducibility

**Why SHA tags?**
- Immutable - never changes
- Traceable - directly linked to git commit
- Reproducible - exact same code every time

### Branch Tags (Staging)

**Format:** `{branch-name}`  
**Purpose:** Latest build from that branch  
**Usage:** Staging environments (always latest)

**Warning:** Branch tags move with each build. Use SHA tags for production.

### Version Tags (Production)

**Format:** `v{major}.{minor}.{patch}`  
**Purpose:** Semantic versioning for releases  
**Usage:** Production releases, version tracking

**Best Practice:** Also use SHA or digest for actual deployment.

### Latest Tag

**Format:** `latest`  
**Purpose:** Most recent production release  
**Usage:** Quick testing, not recommended for production

## Image Digests

Every build produces a unique **digest** (SHA256 hash of image contents):

```
sha256:abc123def456...
```

**Why digests matter:**
- More immutable than tags (tags can be overwritten)
- Exact byte-for-byte reproduction
- Required for supply chain security
- Used in production deployments

**Finding the digest:**
- Check GitHub Actions job summary
- Check staging/production deployment issues
- Use `docker inspect ghcr.io/steveclarke/lr-backend:sha-abc123 --format='{{.RepoDigests}}'`

## Pulling Images

### Authenticate to GHCR

```bash
# Using GitHub Personal Access Token
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# On deployment server (using deploy user's token)
echo $GITHUB_TOKEN | docker login ghcr.io -u deploy --password-stdin
```

### Pull by SHA (Recommended)

```bash
docker pull ghcr.io/steveclarke/lr-backend:sha-9c68c4a
```

### Pull by Digest (Most Secure)

```bash
docker pull ghcr.io/steveclarke/lr-backend@sha256:abc123def456...
```

### Pull by Version

```bash
docker pull ghcr.io/steveclarke/lr-backend:v1.0.0
```

## Build Process

### Build Steps

1. **Checkout code** at specific commit
2. **Set up Docker Buildx** for advanced features
3. **Authenticate to GHCR** using GitHub token
4. **Build image** from `backend/Dockerfile`
5. **Tag image** with SHA, branch/version, and latest (if applicable)
6. **Push to GHCR** with all tags
7. **Extract digest** for reproducibility
8. **Output summary** with pull commands

### Build Caching

Builds use GitHub Actions cache for speed:
- Cache Docker layers between builds
- Faster builds for small changes
- Automatic cache invalidation

### Build Time

- **First build:** ~5-10 minutes (no cache)
- **Subsequent builds:** ~2-5 minutes (with cache)

## Troubleshooting

### Build Failed

1. Check Actions tab for error logs
2. Common issues:
   - Dockerfile syntax errors
   - Missing dependencies in base image
   - Build context too large

### Can't Pull Image

1. Check authentication:
   ```bash
   docker login ghcr.io -u USERNAME
   ```

2. Verify image exists:
   ```bash
   docker pull ghcr.io/steveclarke/lr-backend:master
   ```

3. Check package visibility in GitHub settings

### Wrong Image Pulled

Use SHA or digest for immutable references:
```bash
# Not this (moves with each build)
docker pull ghcr.io/steveclarke/lr-backend:master

# This (immutable)
docker pull ghcr.io/steveclarke/lr-backend:sha-9c68c4a
```

## Integration with Deployment

### Current State (Placeholder)

Deployment placeholder issues now include:
- Docker image tags
- Image digest
- Pull commands

### Future State (Real Deployment)

Your `deploy/bin/deploy` script will:
1. Read image tag from deployment trigger
2. Pull specific image: `ghcr.io/steveclarke/lr-backend:sha-abc123`
3. Deploy using `docker compose pull && docker compose up -d`
4. Verify deployment health

**Example:**
```bash
export BACKEND_IMAGE=ghcr.io/steveclarke/lr-backend:sha-9c68c4a
bin/deploy staging
```

## Security Best Practices

1. **Use SHA or digest tags in production** - Not branch or latest tags
2. **Authenticate properly** - Use GitHub tokens, not personal credentials
3. **Scan images** - Consider adding vulnerability scanning (future)
4. **Private registry** - Keep images private until ready for public release

## References

- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/)
```

### Step 5: Test the Workflow

**Time Estimate:** 45 minutes

**Test 1: Staging Build (Merge to Master)**

1. Create a test PR with a small change
2. Merge to master
3. Verify build workflow triggers
4. Check Actions tab for build progress
5. Verify image pushed to GHCR:
   - `ghcr.io/steveclarke/lr-backend:sha-abc123`
   - `ghcr.io/steveclarke/lr-backend:master`
6. Check staging placeholder issue includes image info
7. Try pulling the image locally

**Test 2: Production Build (Version Tag)**

1. Create and push a test tag: `v0.1.1`
2. Verify build workflow triggers
3. Check Actions tab for build progress
4. Verify image pushed to GHCR:
   - `ghcr.io/steveclarke/lr-backend:sha-def456`
   - `ghcr.io/steveclarke/lr-backend:v0.1.1`
   - `ghcr.io/steveclarke/lr-backend:latest`
5. Check production placeholder issue includes image info
6. Try pulling the image locally

**Test 3: Manual Deploy with Built Image**

```bash
# Pull the newly built image
docker pull ghcr.io/steveclarke/lr-backend:sha-abc123

# Verify it runs
docker run --rm ghcr.io/steveclarke/lr-backend:sha-abc123 bin/rails --version
```

### Step 6: Configure GHCR Package Settings

**Time Estimate:** 15 minutes

After first successful build:

1. Go to GitHub → Packages
2. Find `lr-backend` package
3. Click "Package settings"
4. Configure:
   - **Visibility:** Private (or public if desired)
   - **Access:** Add deploy user if needed
   - **Description:** "LinkRadar Backend API Server"
   - **Link to repository:** Ensure linked

## Deliverables

- [ ] `.github/workflows/build-backend.yml` - Docker build workflow
- [ ] Updated `.github/workflows/deploy-staging-placeholder.yml` - References built images
- [ ] Updated `.github/workflows/deploy-production-placeholder.yml` - References built images
- [ ] `project/guides/deployment/docker-builds.md` - Complete documentation
- [ ] Test images pushed to GHCR with proper tags
- [ ] GHCR package configured and accessible

## Success Criteria

- ✅ Build triggers automatically on merge to master
- ✅ Build triggers automatically on version tag push
- ✅ Images pushed to GHCR with correct tags
- ✅ SHA tags are immutable and traceable to commits
- ✅ Image digests captured for reproducibility
- ✅ Staging placeholder issues include image metadata
- ✅ Production placeholder issues include image metadata
- ✅ Can pull and run built images locally
- ✅ Build caching works (subsequent builds faster)
- ✅ Documentation covers all tagging scenarios

## Time Estimate

**Total:** ~4 hours

- Build workflow: 90 minutes
- Update placeholders: 60 minutes
- Documentation: 60 minutes
- Testing: 45 minutes
- GHCR setup: 15 minutes

## Next Steps

After completing this phase:

1. **Phase 5: Staging Deployment Automation** - Replace staging placeholder with real deploy
2. **Phase 6: Production Deployment Automation** - Replace production placeholder with real deploy

You'll have everything needed for real deployments:
- ✅ Validated code (Phase 2)
- ✅ Deployment triggers (Phase 3)
- ✅ Docker images ready (Phase 4)
- 🔜 Deploy to staging automatically
- 🔜 Deploy to production on tag

## Notes

- **GITHUB_TOKEN** has automatic GHCR write access (no extra secrets needed)
- **Build caching** speeds up subsequent builds significantly
- **SHA tags** are the source of truth for deployments
- **Digests** provide even stronger guarantees than tags
- Your existing `deploy/bin/deploy` script already supports custom `BACKEND_IMAGE`
- This doesn't change your local development workflow

## Migration Path

You can continue building locally during transition:
- Phase 4 automation runs in parallel
- Test automated builds before trusting them
- Keep local build process as backup
- Once confident, remove local build scripts

## References

- [GitHub Actions: Docker Build](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [GHCR Authentication](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry)
- [Semantic Versioning](https://semver.org/)

