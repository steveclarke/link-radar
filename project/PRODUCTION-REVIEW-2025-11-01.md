# Link Radar Production Deployment Review
**Date**: November 1, 2025  
**Reviewer**: _______________  
**Status**: 🔍 Pending Review

---

## Overview

This document provides a comprehensive checklist for reviewing the Link Radar production deployment completed on November 1, 2025. Review each section systematically and check off items as you verify them.

---

## Docker & Build System

- [ ] Review `backend/bin/docker-build` script (defaults to linux/amd64)
  - Verify cross-platform build using `docker buildx`
  - Check `--local` flag for local-only builds
  - Confirm version tagging from VERSION file

- [ ] Review `backend/bin/docker-push` script (GHCR push logic)
  - Verify tags both `:version` and `:latest`
  - Check GHCR repository naming: `ghcr.io/steveclarke/lr-backend`

- [ ] Review `backend/bin/docker-helpers.sh` (shared functions)
  - Verify `get_version` function reads VERSION file correctly
  - Check `get_repo` function returns correct GHCR path
  - Review color output functions (log, info, warn, error)

- [ ] Verify `backend/VERSION` file (0.1.0)
  - Confirm current version is 0.1.0
  - Understand version update process for releases

- [ ] Review `backend/Dockerfile` (Ruby 3.4.7, Rails 8.1, multi-stage)
  - Multi-stage build (base → build → final)
  - Ruby 3.4.7 with jemalloc and YJIT enabled
  - Proper layer caching for dependencies
  - Non-root user (rails:1000)
  - Bootsnap precompilation

---

## Deployment Automation

- [ ] Review `deploy/bin/deploy` script (automated SSH deployment)
  - Environment variable validation (DEPLOY_HOST, RAILS_MASTER_KEY, etc.)
  - SSH connectivity check
  - Git sparse checkout setup
  - Environment file generation with URL-encoded passwords
  - GHCR authentication
  - Service orchestration with health checks

- [ ] Review `deploy/bin/setup` script (initial server setup)
  - Docker and Docker Compose version checks
  - Directory structure creation
  - Environment template copying
  - User guidance messages

- [ ] Review utility scripts: `up`, `down`, `logs`, `console`, `runner`
  - `up`: Starts all services with proper startup message
  - `down`: Stops services cleanly
  - `logs`: Tails backend logs by default, accepts service parameter
  - `console`: Opens Rails console in backend container
  - `runner`: Executes Rails runner commands

- [ ] Review `deploy/compose.yml` (service definitions, networks)
  - Backend service: image, env_file, networks (default + caddy_net), healthcheck
  - Runner service: profile-based, one-off commands
  - Postgres service: PostgreSQL 18, volume mount at `/var/lib/postgresql`, healthcheck
  - Redis service: Redis 7-alpine, AOF persistence, healthcheck
  - Network configuration: default (internal) + caddy_net (external)
  - Volume definitions: postgres_data, redis_data with explicit names

- [ ] Review environment templates: `env.template`, `backend.env.template`, `postgres.env.template`
  - Main env.template: BACKEND_IMAGE configuration
  - backend.env.template: Rails environment, master key, database URL, Redis URL
  - postgres.env.template: Database credentials matching backend config

---

## Configuration Files

- [ ] Review `backend/config/core.yml` (CORS, API settings)
  - Default CORS origins include localhost, production URL, Chrome/Firefox extensions
  - Production inherits from default (includes extension patterns)
  - API key configuration (overridden by CORE_API_KEY env var)
  - Frontend URL configuration

- [ ] Review `backend/config/initializers/cors.rb` (CORS middleware)
  - Uses `CoreConfig.cors_origins` for dynamic configuration
  - Supports regex patterns for extension origins
  - Credentials enabled for cookies/auth headers
  - All HTTP methods allowed

- [ ] Review `backend/config/environments/production.rb` (SSL, logging)
  - SSL enforcement: `config.force_ssl = true`
  - Assumes SSL termination at reverse proxy: `config.assume_ssl = true`
  - Logging to STDOUT with request IDs
  - Health check silence: `/up` endpoint not logged

- [ ] Review `deploy/compose.yml` network configuration (caddy_net)
  - Backend service connected to both `default` and `caddy_net`
  - `caddy_net` defined as external network
  - Allows Caddy container to proxy to backend

---

## Production Environment

- [ ] Review server setup on prime.clevertakes.com (Ubuntu 24.04)
  - SSH access as `deploy` user
  - Docker and Docker Compose installed
  - Firewall (UFW) configured for ports 22, 80, 443
  - Directory structure: `~/docker/link-radar/deploy/` and `~/docker/caddy/`

- [ ] Review Docker images at ghcr.io/steveclarke/lr-backend
  - Images built for linux/amd64 architecture
  - Tagged with version (0.1.0) and latest
  - Publicly accessible package

- [ ] Review production API at https://api.linkradar.app
  - SSL certificate from Let's Encrypt (valid)
  - HTTP/2 and HTTP/3 enabled
  - `/up` health check endpoint responds 200 OK
  - API endpoints require Bearer token authentication

- [ ] Test API authentication with Bruno
  - Production environment configured with correct baseUrl
  - API key stored in Bruno secrets
  - Test creating, reading, updating, deleting links and tags

---

## Bruno API Client

- [ ] Review `backend/bruno/environments/Production.bru`
  - baseUrl: `https://api.linkradar.app`
  - apiKey defined in vars:secret section

- [ ] Verify API key is set in Bruno secrets
  - API Key: `lSuHj9XV9hHub1D2VELqq6M/KNlhu9ZxmFw6gMP1RJk=`
  - Stored securely in Bruno's secret variables

- [ ] Test all API endpoints in Bruno
  - Links: List, Get, Create, Update, Delete, Find by URL
  - Tags: List, Get, Create, Update, Delete, Search

---

## Documentation

- [ ] Review `deploy/README.md` (deployment instructions)
  - Overview of services and architecture
  - Prerequisites and initial setup instructions
  - Configuration file explanations
  - Building backend images (defaults to linux/amd64)
  - Deployment procedures (automated and manual)
  - Operations and maintenance tasks
  - Troubleshooting guide

- [ ] Review `deploy/DEPLOY-QUICKSTART.md` (automated deployment)
  - Environment variable requirements
  - One-command deployment instructions
  - Post-deployment verification steps

- [ ] Review `deploy/DEPLOYMENT-CHECKLIST.md` (manual steps)
  - Step-by-step checklist for manual deployment
  - Server preparation tasks
  - Configuration setup
  - Service startup and verification

- [ ] Review `deploy/REVERSE-PROXY-OPTIONS.md` (Caddy vs Traefik vs Cloudflare)
  - Comparison of three reverse proxy options
  - Pros/cons of each approach
  - Setup instructions for Caddy (what we chose)
  - Decision guide for choosing a proxy solution

---

## Key Issues Resolved

### Ruby 3.4 + Zeitwerk Eager Loading Issue
- **Problem**: Developer tooling code in `lib/link_radar/` was being eager-loaded in production, triggering Ruby 3.4 + Zeitwerk conflict with `bundled_gems.rb`
- **Solution**: Reorganized to `lib/dev/` directory structure and updated autoload ignore list
- **Result**: Production boots successfully with default settings (eager_load=true, Bootsnap enabled)
- **Reference**: `project/notes/ruby-34-zeitwerk-eager-load-SUMMARY.md`

### CORS Configuration for Extensions
- **Problem**: Chrome extension blocked by CORS policy
- **Solution**: Added Chrome/Firefox extension patterns to default CORS origins in `config/core.yml`
- **Result**: Extensions can now make authenticated API requests
- **Pattern**: `/chrome-extension:\/\/.*/` and `/moz-extension:\/\/.*/`

### Cross-Platform Docker Builds
- **Problem**: Building on Mac ARM64 created images incompatible with Linux AMD64 servers
- **Solution**: Updated `bin/docker-build` to use `docker buildx` with `--platform linux/amd64` by default
- **Result**: Images work on production servers even when built on Mac
- **Option**: `--local` flag available for faster local-only builds

### SSL with Caddy + Let's Encrypt
- **Problem**: Need HTTPS for production API
- **Solution**: Deployed Caddy reverse proxy with automatic Let's Encrypt SSL
- **Result**: `https://api.linkradar.app` with valid SSL certificate, auto-renewal configured
- **Benefits**: HTTP/2, HTTP/3, automatic HTTP→HTTPS redirect

---

## Files Changed/Created Today

### New Files
- `backend/bin/docker-build` - Cross-platform build script
- `backend/bin/docker-push` - GHCR push script  
- `backend/bin/docker-helpers.sh` - Shared functions
- `backend/VERSION` - Version tracking (0.1.0)
- `deploy/bin/deploy` - Automated deployment script
- `deploy/DEPLOY-QUICKSTART.md` - Quick start guide
- `deploy/REVERSE-PROXY-OPTIONS.md` - Reverse proxy comparison
- `backend/bruno/environments/Production.bru` - Production API config

### Modified Files
- `backend/config/core.yml` - Added production URL to default CORS origins
- `deploy/compose.yml` - Added caddy_net network configuration
- `deploy/README.md` - Updated build instructions for cross-platform builds

### Server State (on prime.clevertakes.com)
- Created: `~/docker/caddy/` with Caddyfile and compose.yml
- Created: `~/docker/link-radar/deploy/` with full deployment
- Running: Caddy container with SSL certificates
- Running: Link Radar backend + postgres + redis
- Stopped: nginx (disabled to free ports 80/443 for Caddy)

---

## 1Password Credential Storage

### Recommended Setup

Create a **Server** item in 1Password:

**Item Name**: `LinkRadar Production`

**Basic Fields**:
- **URL**: `https://api.linkradar.app`
- **Server**: `prime.clevertakes.com` (107.191.43.235)
- **Username**: `deploy`
- **SSH Key**: Reference to existing SSH key or inline

**Custom Fields** (Add More section):
- **API Key**: `lSuHj9XV9hHub1D2VELqq6M/KNlhu9ZxmFw6gMP1RJk=`
- **Database Password**: [Retrieve from server: `~/docker/link-radar/deploy/env/postgres.env`]
- **Rails Master Key**: [Retrieve from server: `~/docker/link-radar/deploy/env/backend.env`]
- **GitHub Token**: [Reference to existing PAT for GHCR access]
- **Docker Registry**: `ghcr.io/steveclarke/lr-backend:latest`

**Notes Section**:
```
Production Environment for Link Radar

Deployment:
- Location: ~/docker/link-radar/deploy
- Deployed via: bin/deploy script
- DNS: api.linkradar.app (Vultr DNS)

Services:
- Backend: Rails 8.1.1 + Ruby 3.4.7 (port 3000, internal)
- PostgreSQL: 18 (postgres:5432)
- Redis: 7 (redis:6379)
- Caddy: Reverse proxy on ports 80/443

Caddy Configuration:
- Location: ~/docker/caddy/
- Config: ~/docker/caddy/Caddyfile
- SSL Certificates: Auto-managed by Caddy (Let's Encrypt)

Quick Commands:
ssh deploy@prime.clevertakes.com
cd ~/docker/link-radar/deploy
docker compose ps
docker compose logs -f backend
```

---

## Caddy Configuration Reference

### Current Setup (Deployed)

**Location**: `prime.clevertakes.com` at `~/docker/caddy/`

**Caddyfile** (`~/docker/caddy/Caddyfile`):
```caddyfile
# Link Radar Backend API
api.linkradar.app {
    reverse_proxy linkradar-backend:3000
}

# Keep old domain for now (can remove later)
prime.clevertakes.com {
    reverse_proxy linkradar-backend:3000
}

# Future apps can be added here
# app.example.com {
#     reverse_proxy other-app:8080
# }
```

**Docker Compose** (`~/docker/caddy/compose.yml`):
```yaml
name: caddy

services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"  # HTTP/3
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - caddy_net

volumes:
  caddy_data:
    name: caddy_data
  caddy_config:
    name: caddy_config

networks:
  caddy_net:
    name: caddy_net
    driver: bridge
```

### Key Benefits
- Automatic HTTPS with Let's Encrypt (zero configuration)
- HTTP → HTTPS redirect automatic
- Certificate auto-renewal
- HTTP/2 and HTTP/3 support
- Dead simple to add new apps

### Adding New Applications

1. Edit Caddyfile, add new domain block
2. Ensure app container is on `caddy_net` network in its compose.yml
3. Reload Caddy: `docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile`

### Caddy Maintenance

**Update Caddy**:
```bash
cd ~/docker/caddy
docker compose pull
docker compose up -d
```

**View Logs**:
```bash
docker compose logs -f
```

**Check Certificates**:
```bash
docker compose exec caddy caddy list-certificates
```

**Backup SSL Certificates**:
```bash
docker run --rm -v caddy_data:/data -v $(pwd):/backup alpine tar czf /backup/caddy-backup.tar.gz -C /data .
```

---

## TODO: Future Caddy Discussion

- [ ] Can Caddy serve frontend static files? (YES - very common use case)
  - Investigate serving Vue.js/React SPA from Caddy
  - Consider file_server directive for static assets
  - Evaluate fallback routing for SPA

- [ ] Strategy for multiple apps on one server
  - Document subdomain vs path-based routing
  - Plan network topology for multiple app containers
  - Consider resource allocation and isolation

- [ ] Create separate caddy-config repository
  - Store reusable Caddy configurations
  - Version control Caddyfiles for different environments
  - Share across multiple servers/projects

- [ ] Document SSL certificate backup strategy
  - Schedule regular backups of caddy_data volume
  - Test certificate restore procedure
  - Document renewal troubleshooting

---

## Review Sign-Off

**Reviewed By**: _______________  
**Date**: _______________  
**Status**: ⬜ Approved  ⬜ Needs Changes  

**Notes**:
```


```

---

## Next Steps After Review

1. [ ] Store all credentials in 1Password as documented above
2. [ ] Retrieve database password and Rails master key from server
3. [ ] Create Caddy configuration reference repository
4. [ ] Schedule regular backups for database and SSL certificates
5. [ ] Set up monitoring/alerting for production services
6. [ ] Document disaster recovery procedures

