# LR001 - Core Infrastructure Setup

## Overview

Build the foundational infrastructure for LinkRadar MVP following the Rails 8.1 API + Nuxt 4 SPA architecture. This establishes the development and deployment environment before implementing features.

**Goal**: Have a working full-stack skeleton deployed to VPS where you can access a protected dashboard, view links, and add new bookmarks. Single-user MVP with minimal auth.

## Table of Contents

- [LR001 - Core Infrastructure Setup](#lr001---core-infrastructure-setup)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Tech Stack Summary](#tech-stack-summary)
  - [Implementation Phases](#implementation-phases)
    - [Phase 1: Backend Foundation (Rails API)](#phase-1-backend-foundation-rails-api)
    - [Phase 2: Frontend Foundation (Nuxt SPA)](#phase-2-frontend-foundation-nuxt-spa)
    - [Phase 3: Development Environment (Hybrid Approach)](#phase-3-development-environment-hybrid-approach)
    - [Phase 4: Production Deployment Infrastructure](#phase-4-production-deployment-infrastructure)
  - [Superthread Workflow](#superthread-workflow)
    - [Planning Card (Planning Board)](#planning-card-planning-board)
    - [Development Cards (Development Board)](#development-cards-development-board)
    - [Module Updates](#module-updates)
  - [Sequential Execution](#sequential-execution)
  - [Success Criteria (Overall)](#success-criteria-overall)
  - [Next Steps After Infrastructure](#next-steps-after-infrastructure)
  - [Notes](#notes)

## Tech Stack Summary

- **Backend**: Rails 8.1 (API-only mode)
- **Frontend**: Nuxt 4 (SPA mode with TypeScript)
- **UI Components**: Nuxt UI 4
- **Database**: PostgreSQL 18 with UUIDv7 primary keys
- **Job Queue**: GoodJob (Postgres-backed Active Job)
- **Cache**: Redis (caching, rate limiting)
- **Auth**: HTTP Basic Auth (MVP - single user)
- **Reverse Proxy**: Traefik
- **Deployment**: Docker Compose on VPS

**References**:
- [Rails 8.1 API Documentation](https://guides.rubyonrails.org/api_app.html)
- [GoodJob](https://github.com/bensheldon/good_job) - Postgres-backed job queue with dashboard UI
- Nuxt 4 with improved performance and developer experience
- Nuxt UI 4 for production-ready Vue components

## Implementation Phases

### Phase 1: Backend Foundation (Rails API)

**LR001-1: Rails API Skeleton**

Create the basic Rails 8.1 API structure:
- Initialize Rails 8.1 project with API-only mode (`rails new backend --api`)
- Set up database configuration for PostgreSQL
- Configure CORS for SPA communication (rack-cors gem)
- **Set up API versioning**: namespace all routes under `/api/v1`
- Verify built-in health check endpoint (`/up`) is working
- Set up basic API routing structure

**Success Criteria**:
- [ ] Rails responds to `GET /up` with 200 status (built-in health check)
- [ ] All API routes namespaced under `/api/v1`
- [ ] Project follows Rails 8.1 API best practices
- [ ] Environment configuration documented in README

**LR001-2: PostgreSQL Database Setup**

Set up database and migrations scaffolding:
- Create initial Docker Compose file with PostgreSQL 18 service
- Configure Rails database connection (database.yml)
- Enable `pgcrypto` extension for UUIDv7 support
- Create initial migration for `bookmarks` table (UUIDv7 primary key, url, title, description, content_text, metadata jsonb, timestamps)
- Create migration for GoodJob tables (`rails good_job:install`)
- Set up database seeder with sample bookmarks
- Test database connection and migrations

**Success Criteria**:
- [ ] PostgreSQL 18 running via Docker Compose
- [ ] Rails successfully connects to database
- [ ] UUIDv7 primary keys working correctly
- [ ] Migrations run without errors (`rails db:migrate`)
- [ ] GoodJob tables created successfully
- [ ] Can seed sample bookmarks (`rails db:seed`)

**Note**: No users table for MVP - single user, no auth system. Add users/auth when ready for multi-user support.

**LR001-3: Simple Auth (MVP - Single User)**

Implement minimal authentication for MVP:

**Rails API**:
- Set up Bearer token validation middleware
- Single static API key in environment variable (`LINKRADAR_API_KEY`)
- Validate `Authorization: Bearer {token}` header on all API requests
- No database, no users table, no sessions

**Nuxt Frontend**:
- Set up HTTP Basic Auth on Nuxt frontend
- Credentials in environment variables (`NUXT_BASIC_AUTH_USERNAME`, `NUXT_BASIC_AUTH_PASSWORD`)
- Protect entire Nuxt app with basic auth prompt

**Success Criteria**:
- [ ] Rails API protected by Bearer token validation
- [ ] Nuxt frontend protected by HTTP Basic Auth
- [ ] API key never exposed to browser
- [ ] Users authenticate to Nuxt, Nuxt authenticates to Rails
- [ ] Works for solo developer use

**Note**: This is MVP-only auth. Replace with proper user auth system (registration, multi-user, etc.) when ready for broader use.

### Phase 2: Frontend Foundation (Nuxt SPA)

**LR001-4: Nuxt SPA Skeleton**

Create basic Nuxt 4 application:
- Start from official Nuxt 4 template (choose appropriate starter from nuxt.com/templates)
- Initialize Nuxt 4 project in SPA mode (no SSR)
- Configure TypeScript
- Set up Tailwind CSS with custom configuration
- Install and configure Nuxt UI 4 component library
- Configure TanStack Query for data fetching and caching
- Create API client for Rails backend communication
- Create basic layout with navigation using Nuxt UI components

**Success Criteria**:
- [ ] Nuxt 4 app runs in development mode
- [ ] Can make authenticated requests to Rails API health check
- [ ] Tailwind CSS working with custom theme
- [ ] Nuxt UI 4 components render properly
- [ ] TypeScript compilation working

**LR001-5: Frontend with API Proxy**

Connect Nuxt to Rails API via server-side proxy:
- Create Nuxt server middleware to proxy `/api/*` requests to Rails
- Add `Authorization: Bearer {token}` header server-side (from `LINKRADAR_API_KEY` env var)
- Configure Nuxt API client to call local `/api/*` (proxied to Rails)
- Create basic dashboard page
- Create link list view
- Create "add link" form

**Success Criteria**:
- [ ] Nuxt server middleware proxies requests to Rails API
- [ ] Bearer token added server-side (never exposed to browser)
- [ ] Can view dashboard
- [ ] Can add links via form
- [ ] Can view saved links list
- [ ] Basic UI navigation works with Nuxt UI components

### Phase 3: Development Environment (Hybrid Approach)

**LR001-6: Local Development Stack**

Create development environment with dockerized services and native apps:

**Dockerized Services** (via Docker Compose):
- PostgreSQL 18 container
- Redis 7 container
- pg-backup container (for testing backups)

**Native Applications** (run directly on developer machine):
- Rails API (Falcon server) - runs locally, connects to dockerized Postgres/Redis
- Nuxt dev server - runs locally with hot reload
- Use `mise` for version management (Ruby 3.4.x, Node.js, Go 1.25+)

**Setup Tasks**:
- Create Docker Compose file for infrastructure services only
- Configure Rails to connect to dockerized Postgres/Redis
- Configure Nuxt to proxy API requests to local Rails
- Set up `.mise.toml` with required tool versions
- Create development scripts for common tasks
- Document local setup process

**Success Criteria**:
- [ ] Infrastructure services run with `docker compose up`
- [ ] Rails API runs natively with `mise exec rails server`
- [ ] Nuxt runs natively with hot reload
- [ ] All services can communicate (apps → dockerized services)
- [ ] Database persists across container restarts
- [ ] Tool versions managed via mise
- [ ] Development workflow documented

### Phase 4: Production Deployment Infrastructure

**LR001-7: VPS Deployment with Traefik**

Set up production deployment infrastructure:
- Create production Docker Compose configuration
- Configure Traefik reverse proxy:
  - Automatic SSL via Let's Encrypt
  - Route `/api/*` to Rails container
  - Route `/*` to Nuxt server container
- Build optimized production images:
  - Rails: Ruby container with Falcon in production mode
  - Nuxt: Node container running Nuxt server (SPA mode)
- Create deployment scripts and documentation
- Configure production environment variables
- Set up basic monitoring/logging

**Success Criteria**:
- [ ] Application accessible via HTTPS on VPS
- [ ] SSL certificates auto-renewing
- [ ] API routes correctly proxied to Rails
- [ ] Frontend served efficiently via Nuxt server (Node container)
- [ ] Zero-downtime deployment process documented
- [ ] Production environment secured (firewall, secrets management)

## Superthread Workflow

### Planning Card (Planning Board)
- **Card**: LR001 - Core Infrastructure Setup
- **Board**: Planning → Plan
- **Linked to**: Infrastructure module (card 62) under Platform domain (card 25)
- **Tags**: `mvp`, `infrastructure`, `phase-1`
- **Planning docs**: `/project/work-items/LR001-core-infrastructure/plan.md`

### Development Cards (Development Board)
Create 7 child cards on Development board, each linked to LR001:

1. **LR001-1: Rails API Skeleton** → To Do
2. **LR001-2: PostgreSQL Database Setup** → To Do
3. **LR001-3: Basic Authentication (MVP)** → To Do
4. **LR001-4: Nuxt SPA Skeleton** → To Do
5. **LR001-5: Frontend with Basic Auth** → To Do
6. **LR001-6: Local Docker Development** → To Do
7. **LR001-7: VPS Deployment** → To Do

**Note**: Cards 3 & 5 use HTTP Basic Auth for MVP. Replace with proper auth system post-MVP.

### Module Updates
As work progresses:
- **Start LR001-1**: Move "Infrastructure" module to "In Development"
- **Complete LR001-7**: Move "Infrastructure" module to "MVP Complete"

## Sequential Execution

Work through phases in order:
1. Complete **Phase 1** (backend) before starting Phase 2
2. Complete **Phase 2** (frontend) before starting Phase 3
3. Complete **Phase 3** (local dev) before starting Phase 4
4. Each card should move: To Do → Doing → In Review → Done

Validate each phase before proceeding:
- Test endpoints/features manually
- Ensure code quality and documentation
- Commit working code at each step

## Success Criteria (Overall)

MVP infrastructure is complete when:
- [ ] Can visit LinkRadar on HTTPS domain
- [ ] Can authenticate to Nuxt frontend with Basic Auth
- [ ] Can view dashboard with saved links
- [ ] Can add new links via web UI
- [ ] Nuxt proxies API requests to Rails with API key (server-side)
- [ ] API health check endpoint (`/up`) responds
- [ ] Local development environment fully functional (mise + Docker services)
- [ ] Production deployment automated and documented
- [ ] Infrastructure module marked "MVP Complete"

**Post-MVP**: Replace layered auth with proper user authentication (registration, login, per-user API tokens, etc.) when ready for multi-user support.

## Next Steps After Infrastructure

Once LR001 is complete, move to feature development:
- **LR002**: Link capture functionality (manual add via web UI)
- **LR003**: Content extraction and archival
- **LR004**: LLM-powered auto-tagging
- **LR005**: Search and discovery
- **LR006**: Browser extension
- **LR007**: CLI tool

## Notes

- Focus on getting infrastructure working, not perfect
- Document as you go (especially deployment and local setup)
- Keep it simple - avoid over-engineering
- Production deployment doesn't need to be fancy, just working
- Use Rails 8.1 and Nuxt 4 defaults where possible
- Leverage Nuxt UI 4 for consistent, accessible components
- Rails API mode removes all view/asset pipeline complexity

