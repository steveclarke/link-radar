# Link Radar - Automated Deployment Quick Start

Deploy Link Radar to your production server in one command. No SSH sessions, no manual config - just set your variables and go! ☕

## Prerequisites

- Production server ready with Docker and Docker Compose
- SSH access configured (key-based auth recommended)
- Backend image pushed to GHCR (`cd backend && bin/docker-push`)
- Rails master key from `backend/config/master.key`
- GitHub Personal Access Token with `read:packages` permission

## The One-Command Deploy

```bash
cd deploy

# Set your environment variables
export DEPLOY_HOST=YOUR_SERVER_IP
export RAILS_MASTER_KEY=$(cat ../backend/config/master.key)
export DB_PASSWORD=$(openssl rand -base64 32)
export GITHUB_TOKEN=ghp_your_github_token

# Deploy!
bin/deploy
```

## What It Does

The script automatically:
1. ✅ SSHs to your server
2. ✅ Clones deploy directory only (sparse checkout)
3. ✅ Creates environment files with your configs
4. ✅ Authenticates with GitHub Container Registry
5. ✅ Pulls Docker images
6. ✅ Starts services
7. ✅ Verifies deployment

## Full Example

```bash
# Navigate to deploy directory
cd /Users/steve/src/link-radar/deploy

# Set up environment
export DEPLOY_HOST=123.45.67.89
export DEPLOY_USER=deploy  # Optional, defaults to 'deploy'
export RAILS_MASTER_KEY=$(cat ../backend/config/master.key)
export DB_PASSWORD=$(openssl rand -base64 32)
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
export BACKEND_IMAGE=ghcr.io/steveclarke/lr-backend:latest  # Optional

# Check prerequisites first (optional)
bin/deploy --check

# Deploy!
bin/deploy
```

## Environment Variables

### Required

- `DEPLOY_HOST` - Your server IP or hostname
- `RAILS_MASTER_KEY` - From `backend/config/master.key`
- `DB_PASSWORD` - PostgreSQL password (generate with `openssl rand -base64 32`)
- `GITHUB_TOKEN` - GitHub Personal Access Token

### Optional

- `DEPLOY_USER` - SSH user (default: `deploy`)
- `BACKEND_IMAGE` - Backend image (default: `ghcr.io/steveclarke/lr-backend:latest`)
- `BACKEND_PORT` - External port (default: `3000`)
- `GITHUB_USER` - GitHub username (default: `steveclarke`)

## After Deployment

### View Logs
```bash
ssh deploy@YOUR_SERVER_IP 'cd ~/docker/link-radar/deploy && ./bin/logs'
```

### Check Status
```bash
ssh deploy@YOUR_SERVER_IP 'cd ~/docker/link-radar/deploy && docker compose ps'
```

### Rails Console
```bash
ssh deploy@YOUR_SERVER_IP 'cd ~/docker/link-radar/deploy && ./bin/console'
```

### Test Health Endpoint
```bash
curl http://YOUR_SERVER_IP:3000/up
```

## Re-deploying / Updating

To deploy a new version:

1. Build and push new image:
```bash
cd backend
bin/docker-build
bin/docker-push
```

2. Re-run deploy script:
```bash
cd deploy
bin/deploy
```

The script will update the repository, pull new images, and restart services.

## Troubleshooting

### SSH Connection Failed
- Verify SSH access: `ssh deploy@YOUR_SERVER_IP`
- Check SSH key is loaded: `ssh-add -l`
- Use `ssh -v` for verbose connection details

### Docker Login Failed
- Verify GitHub token has `read:packages` scope
- Test locally: `echo $GITHUB_TOKEN | docker login ghcr.io -u steveclarke --password-stdin`

### Services Won't Start
- SSH to server and check logs: `cd ~/docker/link-radar/deploy && bin/logs backend`
- Verify environment variables are correct
- Check `RAILS_MASTER_KEY` is valid

### Health Check Failed
- Give services 30-60 seconds to fully start
- Check backend logs for errors
- Verify database migrations ran successfully

## Manual Deployment

Prefer to do it manually? See [DEPLOYMENT-CHECKLIST.md](./DEPLOYMENT-CHECKLIST.md) for the step-by-step manual process.

## Script Options

```bash
bin/deploy --help     # Show usage information
bin/deploy --check    # Check prerequisites only, don't deploy
```

---

**Pro tip:** Save your environment variables in a local `.env.deploy` file (NOT checked into git) and source it:

```bash
# .env.deploy (add to .gitignore!)
export DEPLOY_HOST=123.45.67.89
export RAILS_MASTER_KEY=xxx
export DB_PASSWORD=yyy
export GITHUB_TOKEN=zzz

# Then deploy:
source .env.deploy && bin/deploy
```

