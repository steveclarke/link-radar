# Current Deployment Status

**Last Updated:** 2025-11-08  
**Status:** Docker build automation complete, manual deployments

## What's Automated ✅

### Docker Image Builds (Phase 4 Complete)

**Trigger:** Every push to `master` or version tag (`v*.*.*`)

**What happens:**
1. Docker image built from `backend/Dockerfile`
2. Image pushed to GitHub Container Registry (GHCR)
3. Images tagged semantically:
   - `master` - Latest from master branch
   - `sha-{commit}` - Specific commit (immutable)
   - `v{version}` - For version tags only
   - `latest` - For version tags only
4. Deployment placeholder issue created with image metadata

**Where:** `.github/workflows/docker-build-push.yml`

**Registry:** `ghcr.io/steveclarke/lr-backend`

**Example tags:**
```bash
ghcr.io/steveclarke/lr-backend:master          # Latest master
ghcr.io/steveclarke/lr-backend:sha-f4f81f5     # Specific commit
ghcr.io/steveclarke/lr-backend:v1.0.0          # Version release
ghcr.io/steveclarke/lr-backend:latest          # Latest release
```

## What's Manual ⚠️

### Production Deployments

**Current process:**
1. SSH to production server
2. Update `docker-compose.yml` image tag to `master`
3. Run `docker compose pull`
4. Run `docker compose up -d`
5. Monitor logs manually

**Current image tag:** `master` (should migrate to SHA-based)

**Location:** Production server

## Current Production Setup

### Docker Compose Configuration

```yaml
services:
  backend:
    image: ghcr.io/steveclarke/lr-backend:master  # ⚠️ Using mutable tag
    # ... other configuration
```

**⚠️ Known issue:** Using `master` tag means image may change unexpectedly

**Recommended:** Switch to SHA-based tags for immutability:
```yaml
services:
  backend:
    image: ghcr.io/steveclarke/lr-backend:sha-f4f81f5  # ✅ Immutable
```

## How to Deploy Right Now

### Manual Deployment Steps

1. **Find the image SHA tag:**
   - Check latest deployment issue: https://github.com/steveclarke/link-radar/issues?q=is%3Aissue+label%3A%22deployment%3A+staging%22
   - Or check GHCR: https://github.com/steveclarke/lr-backend/pkgs/container/lr-backend
   - Note the SHA tag (e.g., `sha-f4f81f5`)

2. **SSH to production server:**
   ```bash
   ssh deploy@production-server
   ```

3. **Update image tag in docker-compose.yml:**
   ```bash
   cd /app
   # Edit docker-compose.yml to use specific SHA tag
   vim docker-compose.yml
   # Change: image: ghcr.io/steveclarke/lr-backend:sha-f4f81f5
   ```

4. **Pull new image:**
   ```bash
   docker compose pull backend
   ```

5. **Deploy:**
   ```bash
   docker compose up -d backend
   ```

6. **Run migrations (if needed):**
   ```bash
   docker compose exec backend rails db:migrate
   ```

7. **Verify:**
   ```bash
   curl http://localhost:3000/up
   docker compose logs -f backend
   ```

### Using the Deploy Script

If you have `deploy/bin/deploy` on production server:

```bash
ssh deploy@production-server
cd /app
./deploy/bin/deploy
```

**Note:** Current script may not support SHA-based tags yet (Phase 5 enhancement)

## How to Rollback

### Quick Rollback

1. **Identify previous working SHA:**
   - Check deployment issues
   - Or check `docker images` on server

2. **Update docker-compose.yml:**
   ```bash
   # Change image tag to previous SHA
   image: ghcr.io/steveclarke/lr-backend:sha-abc1234
   ```

3. **Deploy previous version:**
   ```bash
   docker compose pull backend
   docker compose up -d backend
   ```

## Available Images

### View all tags:
```bash
docker pull ghcr.io/steveclarke/lr-backend:master
docker images ghcr.io/steveclarke/lr-backend
```

### Pull specific version:
```bash
docker pull ghcr.io/steveclarke/lr-backend:sha-f4f81f5
```

### Pull by digest (most immutable):
```bash
docker pull ghcr.io/steveclarke/lr-backend@sha256:73535b02410f108336ae4a725bf3683fe898c1d159ed02ff2e2d184afbaa5e0d
```

## Deployment History

Track deployments via GitHub issues:
- **Staging deployments:** [deployment: staging](https://github.com/steveclarke/link-radar/issues?q=is%3Aissue+label%3A%22deployment%3A+staging%22)
- **Production deployments:** Currently manual, not tracked in issues

Each deployment issue contains:
- Commit SHA
- Image tags
- Docker pull commands
- Deployment timestamp

## Next Phase: Automated Deployments

See [Phase 5 Plan](../../features/LR002-cicd-pipeline/Phase5-Automated-Deployments/plan.md) for roadmap to automate production deployments.

**Goal:** GitHub Actions deploys to production automatically with:
- SHA-based image tags
- Automated health checks  
- Rollback capability
- Deployment tracking

## Quick Reference

### Find latest image:
```bash
# Check GitHub issues for latest deployment
gh issue list --label "deployment: staging" --limit 1

# Or check GHCR directly
open https://github.com/users/steveclarke/packages/container/package/lr-backend
```

### Deploy specific commit:
```bash
# On production server
cd /app
# Edit docker-compose.yml with specific SHA tag
docker compose pull backend
docker compose up -d backend
```

### Check current deployment:
```bash
# On production server
docker compose ps
docker compose logs backend | head -20
curl http://localhost:3000/up
```

### Emergency rollback:
```bash
# On production server
cd /app
# Edit docker-compose.yml back to previous SHA
docker compose pull backend
docker compose up -d backend
```

## Monitoring

### Application Health:
```bash
curl http://localhost:3000/up
```

### Container Status:
```bash
docker compose ps backend
docker compose logs -f backend
```

### Image Information:
```bash
docker inspect ghcr.io/steveclarke/lr-backend:sha-f4f81f5
```

## Troubleshooting

### Image pull fails:
```bash
# Login to GHCR (should not be needed for public images)
echo $GITHUB_TOKEN | docker login ghcr.io -u steveclarke --password-stdin
```

### Container won't start:
```bash
# Check logs
docker compose logs backend

# Check previous container
docker compose logs backend --since 1h
```

### Health check fails:
```bash
# Check application logs
docker compose logs -f backend

# Check if port is accessible
curl -v http://localhost:3000/up

# Exec into container
docker compose exec backend bash
```

## Best Practices

### DO ✅
- Use SHA-based tags for production
- Test in staging first (when available)
- Keep deployment history in GitHub issues
- Document what you deployed and when
- Have rollback plan ready

### DON'T ❌
- Use `latest` tag for production (too mutable)
- Deploy without checking image exists
- Deploy during peak traffic times without testing
- Skip database backups before migrations
- Deploy without monitoring logs

## Resources

- **Docker automation docs:** [project/guides/deployment/docker-automation.md](./docker-automation.md)
- **Phase 4 summary:** [project/features/LR002-cicd-pipeline/Phase4-Docker-Builds/implementation-summary.md](../../features/LR002-cicd-pipeline/Phase4-Docker-Builds/implementation-summary.md)
- **Phase 5 plan:** [project/features/LR002-cicd-pipeline/Phase5-Automated-Deployments/plan.md](../../features/LR002-cicd-pipeline/Phase5-Automated-Deployments/plan.md)
- **Activation checklist:** [project/guides/deployment/activation-checklist.md](./activation-checklist.md)

