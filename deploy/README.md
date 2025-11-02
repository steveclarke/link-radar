# Link Radar Deployment

This directory contains the Docker Compose configuration and utilities for deploying Link Radar.

## Quick Deploy

**First time?** Initialize and deploy in two commands:

```bash
bin/deploy prod --init --deployed    # Setup configuration
bin/deploy prod                       # Deploy
```

See [DEPLOY.md](./DEPLOY.md) for complete deployment guide.

## Table of Contents

- [Link Radar Deployment](#link-radar-deployment)
  - [Quick Deploy](#quick-deploy)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Initial Setup](#initial-setup)
  - [Configuration](#configuration)
  - [Building Backend Images](#building-backend-images)
  - [Deployment](#deployment)
  - [Operations](#operations)
    - [Deploying Updates](#deploying-updates)
  - [Maintenance](#maintenance)
  - [Troubleshooting](#troubleshooting)
  - [Reverse Proxy / SSL](#reverse-proxy--ssl)

## Overview

**Reverse Proxy**: Caddy (automatic HTTPS)  
**URL**: https://api.linkradar.app

**Services**:
- `backend` - Rails API server
- `postgres` - Database with persistent storage
- `redis` - Cache and background jobs
- `runner` - One-off commands (console, migrations)

## Prerequisites

- Linux server with Docker and Docker Compose v2
- SSH access configured

## Initial Setup

### Automated Deployment (Recommended)

```bash
cd deploy

# Initialize environment configuration
bin/deploy prod --init --deployed    # For existing deployment
# OR
bin/deploy prod --init               # For fresh installation

# Deploy
bin/deploy prod
```

See [DEPLOY.md](./DEPLOY.md) for detailed deployment guide.

### Manual Setup on Server

For manual setup without using `bin/deploy`:

```bash
mkdir -p ~/docker && cd ~/docker
git clone --filter=blob:none --sparse https://github.com/steveclarke/link-radar.git
cd link-radar && git sparse-checkout set --no-cone deploy/ && cd deploy
bin/setup
```

Edit `env/*.env` files with your credentials, then `bin/up`.

## Configuration

### Automated Configuration

Use `bin/deploy --init` to create environment configuration:

```bash
bin/deploy prod --init --host=server.com --op=1password-item-id --deployed
```

This creates `.config/prod.env` with deployment settings.

### Server Environment Files

Environment files are in `env/` directory on the server:
- `.env` - Docker Compose variables (image name, ports)
- `env/backend.env` - Rails runtime config
- `env/postgres.env` - Database credentials

**Note**: `bin/deploy` generates these automatically. For manual setup, copy from `*.template` files.

## Building Backend Images

```bash
cd backend
bin/docker-build  # Builds for linux/amd64 by default
bin/docker-push   # Pushes to ghcr.io/steveclarke/lr-backend
```

Version is tracked in `backend/VERSION`. Images tagged with version and `:latest`.

## Deployment

See [DEPLOY.md](./DEPLOY.md) for automated deployment.

For manual deployment on server:
```bash
bin/up                    # Start services
docker compose ps         # Verify status
```

## Operations

**Utility scripts** (`bin/` directory):
- `bin/up` / `bin/down` - Start/stop services
- `bin/logs [service]` - View logs
- `bin/console` - Rails console
- `bin/runner [command]` - Run Rails commands

**Common tasks**:
```bash
bin/logs backend              # View backend logs
bin/console                   # Rails console
bin/runner bin/rails db:migrate  # Run migrations
```

### Deploying Updates

```bash
# 1. Build and push new backend image
cd backend
bin/docker-build
bin/docker-push

# 2. Deploy to server
cd ../deploy
bin/deploy prod
```

**Note**: Subsequent deploys automatically pull latest code and images, then restart services.

## Maintenance

```bash
# Backup database
docker compose exec postgres pg_dump -U linkradar linkradar > backup.sql

# Restore database
cat backup.sql | docker compose exec -T postgres psql -U linkradar linkradar

# Restart service
docker compose restart backend

# Stop all (preserves data)
bin/down
```

## Troubleshooting

**Backend won't start**: Check `bin/logs backend`, verify `RAILS_MASTER_KEY` in `env/backend.env`

**Database errors**: Check `bin/logs postgres`, verify passwords match in `env/backend.env` and `env/postgres.env`

**Services restarting**: Check logs with `bin/logs [service]`, verify healthchecks pass

## Reverse Proxy / SSL

**Current Setup**: Caddy reverse proxy with automatic HTTPS

**URL**: https://api.linkradar.app  
**Location**: `~/docker/caddy/` on server  
**Config**: Caddyfile (simple domain → container mapping)  
**SSL**: Let's Encrypt (auto-renewed)

**Adding apps**: Edit Caddyfile, add domain block, reload Caddy

See server for current Caddy configuration.

