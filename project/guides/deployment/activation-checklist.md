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

## Example: Converting Staging Placeholder to Real Deployment

### Current Placeholder Structure

```yaml
jobs:
  staging-deployment-placeholder:
    steps:
      - name: Create staging deployment issue
        uses: actions/github-script@v8
        # Creates GitHub issue
```

### Real Deployment Structure

```yaml
jobs:
  build:
    steps:
      - name: Build Docker image
      - name: Push to registry
  
  deploy:
    needs: build
    steps:
      - name: Deploy to staging
      - name: Run migrations
      - name: Health checks
      - name: Update deployment issue
```

## Configuration Secrets Required

Add these to GitHub repository secrets before activation:

**Container Registry:**
- `REGISTRY_URL` - Container registry URL
- `REGISTRY_USERNAME` - Registry username
- `REGISTRY_PASSWORD` - Registry password/token

**Staging Environment:**
- `STAGING_DEPLOY_KEY` - SSH key or deployment token
- `STAGING_HOST` - Staging server hostname
- `STAGING_DB_URL` - Database connection string

**Production Environment:**
- `PRODUCTION_DEPLOY_KEY` - SSH key or deployment token
- `PRODUCTION_HOST` - Production server hostname
- `PRODUCTION_DB_URL` - Database connection string

## Health Check Examples

**Basic HTTP health check:**

```yaml
- name: Verify deployment
  run: |
    for i in {1..30}; do
      if curl -f https://staging.linkradar.app/health; then
        echo "Health check passed"
        exit 0
      fi
      echo "Waiting for deployment... ($i/30)"
      sleep 10
    done
    echo "Health check failed"
    exit 1
```

**Database migration verification:**

```yaml
- name: Verify migrations
  run: |
    docker exec backend rails db:migrate:status
```

## Rollback Procedures

**Automatic rollback on failure:**

```yaml
- name: Deploy to production
  id: deploy
  continue-on-error: true
  run: ./deploy.sh

- name: Rollback on failure
  if: steps.deploy.outcome == 'failure'
  run: ./rollback.sh
```

**Manual rollback steps:**

1. Identify last working version tag
2. Re-push that tag to trigger deployment
3. Or manually deploy previous Docker image
4. Verify rollback with health checks

## Testing Strategy

1. **Test in staging first** - Always validate changes in staging
2. **Canary deployments** - Deploy to subset of production first
3. **Blue-green deployments** - Run old and new versions simultaneously
4. **Feature flags** - Enable features gradually

## Monitoring and Alerts

Configure alerts for:
- Deployment failures
- Health check failures
- High error rates after deployment
- Database migration issues
- Resource exhaustion

## Documentation Updates Needed

After activation, update:
- Deployment workflows documentation
- Runbook for on-call engineers
- Architecture diagrams
- Team wiki/handbook
- README files

## Progressive Activation Strategy

**Phase 1: Staging Only**
1. Activate staging deployment
2. Run for 2+ weeks
3. Monitor stability
4. Refine based on issues

**Phase 2: Production (Controlled)**
1. Activate production deployment
2. Deploy only during business hours
3. Manual approval gates
4. One person monitoring

**Phase 3: Production (Automated)**
1. Remove manual approval
2. Deploy any time
3. Automatic rollback on failure
4. Full confidence in automation

## Success Criteria

You've successfully activated deployment automation when:
- Deployments happen without manual intervention
- Failures are automatically detected and handled
- Team trusts the automation
- Deployment frequency increases
- Deployment stress decreases
- Time-to-production reduces significantly

