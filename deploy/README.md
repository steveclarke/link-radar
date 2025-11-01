# Link Radar Production Deployment

This directory contains the Docker Compose configuration and utilities for deploying Link Radar in production.

## Quick Deploy

**🚀 Automated deployment (recommended):** [DEPLOY-QUICKSTART.md](./DEPLOY-QUICKSTART.md) - Deploy in one command via `bin/deploy`

**📋 Manual deployment:** [DEPLOYMENT-CHECKLIST.md](./DEPLOYMENT-CHECKLIST.md) - Step-by-step checklist for manual deployment

## Table of Contents

- [Link Radar Production Deployment](#link-radar-production-deployment)
  - [Quick Deploy](#quick-deploy)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [Understanding .env vs env/\*.env](#understanding-env-vs-envenv)
  - [Prerequisites](#prerequisites)
  - [Initial Setup](#initial-setup)
    - [Sparse Checkout (Recommended for Production)](#sparse-checkout-recommended-for-production)
    - [Full Repository Clone (Development/Testing)](#full-repository-clone-developmenttesting)
  - [Configuration](#configuration)
    - [Main Configuration (.env)](#main-configuration-env)
    - [Backend Configuration (env/backend.env)](#backend-configuration-envbackendenv)
    - [Database Configuration (env/postgres.env)](#database-configuration-envpostgresenv)
  - [Building Backend Images](#building-backend-images)
    - [Version Management](#version-management)
    - [Building the Image](#building-the-image)
    - [Pushing to GitHub Container Registry](#pushing-to-github-container-registry)
  - [Deployment](#deployment)
    - [Starting Services](#starting-services)
  - [Operations](#operations)
    - [Utility Scripts](#utility-scripts)
    - [Common Tasks](#common-tasks)
    - [Deploying Updates](#deploying-updates)
  - [Maintenance](#maintenance)
    - [Backing Up the Database](#backing-up-the-database)
    - [Restoring the Database](#restoring-the-database)
    - [Viewing Container Status](#viewing-container-status)
    - [Restarting a Service](#restarting-a-service)
    - [Cleaning Up](#cleaning-up)
  - [Troubleshooting](#troubleshooting)
    - [Backend won't start](#backend-wont-start)
    - [Database connection errors](#database-connection-errors)
    - [Cannot pull backend image](#cannot-pull-backend-image)
    - [Services keep restarting](#services-keep-restarting)
  - [Reverse Proxy / SSL](#reverse-proxy--ssl)
  - [Additional Resources](#additional-resources)

## Overview

The deployment stack consists of four services:

- **backend**: Ruby on Rails API server
- **postgres**: PostgreSQL 18 database with persistent storage
- **redis**: Redis 7 for caching and background jobs
- **runner**: Utility container for running one-off commands (migrations, console, tasks)

All services are orchestrated using Docker Compose with environment-based configuration.

### Understanding .env vs env/*.env

It's easy to get confused about which variables go where. Here's the key distinction:

- **`.env`** - Variables that Docker Compose itself needs to interpret the compose.yml file (like image names, ports). These are NOT passed into containers.
- **`env/*.env`** - Runtime environment variables that are passed into running containers (like database credentials, API keys, Rails config).

In other words:
- `.env` = Variables for Docker Compose to build/start containers
- `env/*.env` = Variables that containers use at runtime

## Prerequisites

- Docker Engine 20.10+ and Docker Compose v2
- GitHub Container Registry access (for pulling the backend image)
- A server or VM running Linux (Ubuntu 22.04 recommended)

## Initial Setup

### Sparse Checkout (Recommended for Production)

For production servers, clone **only** the deploy directory to avoid having source code on the server:

```bash
mkdir -p ~/docker
cd ~/docker
git clone --filter=blob:none --sparse https://github.com/steveclarke/link-radar.git
cd link-radar
git sparse-checkout set deploy
cd deploy
```

This gives you only the deployment configurations - no source code on production!

### Full Repository Clone (Development/Testing)

For local testing or development:

```bash
git clone <repository-url>
cd link-radar/deploy
```

2. **Run the setup script** to create environment files from templates:

```bash
bin/setup
```

This will:
- Create `.env` from `env.template`
- Create `env/backend.env` from `env/backend.env.template`
- Create `env/postgres.env` from `env/postgres.env.template`
- Verify Docker installation

3. **Authenticate with GitHub Container Registry**:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

You'll need a GitHub Personal Access Token with `read:packages` permission.

## Configuration

### Main Configuration (.env)

Edit `.env` and set:

```bash
# Your backend Docker image from GitHub Container Registry
BACKEND_IMAGE=ghcr.io/your-username/link-radar-backend:latest

# Port to expose the backend API on (default: 3000)
BACKEND_PORT=3000
```

### Backend Configuration (env/backend.env)

Edit `env/backend.env` with your production values:

```bash
# Rails environment settings
RAILS_ENV=production
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true

# Rails master key (from backend/config/master.key)
# CRITICAL: Keep this secret!
RAILS_MASTER_KEY=your_rails_master_key_here

# Database connection
# Use 'postgres' as the host (service name in Docker Compose)
DATABASE_URL=postgresql://linkradar:your_secure_password@postgres:5432/linkradar_production

# Redis connection
# Use 'redis' as the host (service name in Docker Compose)
REDIS_URL=redis://redis:6379/0

# Optional: Adjust based on your needs
RAILS_MAX_THREADS=5
```

### Database Configuration (env/postgres.env)

Edit `env/postgres.env`:

```bash
POSTGRES_USER=linkradar
# IMPORTANT: Change to a strong password that matches DATABASE_URL
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=linkradar_production
```

**Security Note**: The password in `env/postgres.env` must match the password in `env/backend.env` DATABASE_URL.

## Building Backend Images

Before deploying, you need to build the backend Docker image and push it to GitHub Container Registry (GHCR).

### Version Management

The backend uses a `VERSION` file to track releases. The current version is in `backend/VERSION`:

```bash
cat backend/VERSION
# 0.1.0
```

This version is used to tag Docker images. Update this file when releasing new versions.

### Building the Image

From the repository root:

```bash
cd backend
bin/docker-build
```

This builds a Docker image tagged as `lr-backend:VERSION` (e.g., `lr-backend:0.1.0`).

**By default**, the image is built for `linux/amd64` (production servers) using Docker buildx. This ensures the image will work on your production Linux servers even if you're building on a Mac.

**Build options:**

```bash
# Default: Build for linux/amd64 (production-ready)
bin/docker-build

# Build for local platform only (faster for local testing, Mac ARM or Linux)
bin/docker-build --local

# Pass additional Docker build arguments using --
bin/docker-build -- --no-cache
```

### Pushing to GitHub Container Registry

First, authenticate with GHCR (one-time setup):

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

You'll need a GitHub Personal Access Token with `write:packages` permission.

Then push the image:

```bash
cd backend
bin/docker-push
```

This pushes two tags to GHCR:
- `ghcr.io/YOUR_USERNAME/lr-backend:VERSION`
- `ghcr.io/YOUR_USERNAME/lr-backend:latest`

View your images at: `https://github.com/YOUR_USERNAME/link-radar/pkgs/container/lr-backend`

## Deployment

### Starting Services

1. **Pull the latest images**:

```bash
docker compose pull
```

2. **Start all services**:

```bash
bin/up
```

This starts all services in detached mode. The first time it runs, it will:
- Create and prepare the database (via `bin/docker-entrypoint`)
- Run migrations automatically
- Start the Rails server

3. **Verify services are running**:

```bash
docker compose ps
```

All services should show as "running" with healthy status.

## Operations

### Utility Scripts

The `bin/` directory contains convenience scripts for common operations:

- **`bin/up`** - Start all services
- **`bin/down`** - Stop all services
- **`bin/logs [service]`** - View logs (optionally for a specific service)
- **`bin/console`** - Open Rails console in the backend container
- **`bin/runner [command]`** - Run arbitrary commands in the backend container

### Common Tasks

**View logs for all services**:
```bash
bin/logs
```

**View logs for just the backend**:
```bash
bin/logs backend
```

**Open Rails console**:
```bash
bin/console
```

This uses the `runner` service - a dedicated container for one-off commands. It automatically starts a fresh container, runs your command, and cleans up when done.

**Run database migrations**:
```bash
bin/runner bin/rails db:migrate
```

**Check database migration status**:
```bash
bin/runner bin/rails db:migrate:status
```

**Run a Rails task**:
```bash
bin/runner bin/rails your:task:name
```

The `runner` service has all the same environment variables and access as the backend service (database, Redis, etc.) but is designed for interactive and one-off commands rather than serving web requests.

**Note**: The runner service uses the `tools` profile, which means it doesn't start automatically with `bin/up`. It only runs when explicitly called via `docker compose run runner [command]`, which is exactly what we want for a utility container.

### Deploying Updates

To deploy a new version of the backend:

1. Build and push the new image:
```bash
cd ../backend
docker build -t ghcr.io/your-username/link-radar-backend:latest .
docker push ghcr.io/your-username/link-radar-backend:latest
```

2. Pull and restart:
```bash
cd ../deploy
docker compose pull backend
docker compose up -d backend
```

The backend will automatically run migrations on startup via the docker-entrypoint script.

## Maintenance

### Backing Up the Database

```bash
docker compose exec postgres pg_dump -U linkradar linkradar_production > backup.sql
```

### Restoring the Database

```bash
cat backup.sql | docker compose exec -T postgres psql -U linkradar linkradar_production
```

### Viewing Container Status

```bash
docker compose ps
```

### Restarting a Service

```bash
docker compose restart backend
# or
docker compose restart postgres
# or
docker compose restart redis
```

### Cleaning Up

To stop services and remove containers (data volumes are preserved):
```bash
bin/down
```

To remove everything including volumes (⚠️ **DESTRUCTIVE** - deletes all data):
```bash
docker compose down -v
```

## Troubleshooting

### Backend won't start

1. Check logs:
```bash
bin/logs backend
```

2. Verify environment variables are set correctly in `env/backend.env`

3. Ensure `RAILS_MASTER_KEY` is correct

4. Check database connectivity:
```bash
bin/runner bin/rails db:version
```

### Database connection errors

1. Verify postgres is running and healthy:
```bash
docker compose ps postgres
```

2. Check postgres logs:
```bash
bin/logs postgres
```

3. Verify password matches in both `env/backend.env` and `env/postgres.env`

### Cannot pull backend image

1. Verify you're authenticated with GitHub Container Registry:
```bash
docker login ghcr.io
```

2. Check the image name in `.env` matches your actual image

3. Verify you have read access to the GitHub repository/package

### Services keep restarting

1. Check logs for the specific service:
```bash
bin/logs [service-name]
```

2. Look for configuration errors or missing environment variables

3. Verify healthcheck endpoints are responding:
```bash
# For backend
curl http://localhost:3000/up
```

## Reverse Proxy / SSL

Currently, the backend is exposed directly on port 3000. For production use with a domain name and SSL:

- **Reverse Proxy Options:** See [REVERSE-PROXY-OPTIONS.md](./REVERSE-PROXY-OPTIONS.md) for three modern approaches:
  - **Cloudflare Tunnel** (recommended) - Zero SSL management, no open ports
  - **Caddy** - Dead simple self-hosted with automatic HTTPS
  - **Traefik** - Advanced features, Docker labels
- Current deployment works perfectly without these - add when ready

## Additional Resources

- [Docker Compose documentation](https://docs.docker.com/compose/)
- [GitHub Container Registry authentication](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Rails deployment guide](https://guides.rubyonrails.org/configuring.html#rails-general-configuration)
- [Traefik documentation](https://doc.traefik.io/traefik/)

