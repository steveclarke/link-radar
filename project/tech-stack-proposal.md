# LinkRadar - Technology Stack Proposal

**Approach:** Rails API + Nuxt SPA  
**Target:** 4-week MVP for self-hosted deployment

## Table of Contents

- [LinkRadar - Technology Stack Proposal](#linkradar---technology-stack-proposal)
  - [Table of Contents](#table-of-contents)
  - [Architecture Overview](#architecture-overview)
    - [Component Architecture](#component-architecture)
  - [Stack Components](#stack-components)
    - [Frontend: Nuxt 4 SPA](#frontend-nuxt-4-spa)
    - [Backend: Rails 8.1 API](#backend-rails-81-api)
    - [Database: PostgreSQL](#database-postgresql)
    - [CLI Tool: Go](#cli-tool-go)
    - [Browser Extension: Chrome (Manifest V3)](#browser-extension-chrome-manifest-v3)
  - [Authentication \& User Flow](#authentication--user-flow)
    - [MVP Auth Flow (Layered Auth)](#mvp-auth-flow-layered-auth)
    - [Post-MVP: Multi-User Auth (Future)](#post-mvp-multi-user-auth-future)
  - [Data Flow: Link Capture](#data-flow-link-capture)
    - [Via Web UI](#via-web-ui)
    - [Via CLI](#via-cli)
    - [Via Extension](#via-extension)
  - [Deployment Architecture](#deployment-architecture)
    - [Docker Compose Services](#docker-compose-services)
    - [Infrastructure Provisioning: Terraform](#infrastructure-provisioning-terraform)
    - [Environment Configuration](#environment-configuration)
    - [Backup \& Restore](#backup--restore)
  - [Development Workflow](#development-workflow)
    - [Local Development](#local-development)
    - [Version Control](#version-control)
    - [CI/CD (Future)](#cicd-future)
  - [API Design](#api-design)
    - [REST Principles](#rest-principles)
    - [Authentication](#authentication)
    - [Response Format](#response-format)
    - [Rate Limiting](#rate-limiting)
  - [Technology Choices: Rationale](#technology-choices-rationale)
    - [Why Rails?](#why-rails)
    - [Why Falcon?](#why-falcon)
    - [Why Nuxt 4 SPA?](#why-nuxt-4-spa)
    - [Why Rails Session Auth + API Tokens?](#why-rails-session-auth--api-tokens)
    - [Why Self-Hosted Postgres?](#why-self-hosted-postgres)
    - [Why Go for CLI?](#why-go-for-cli)
    - [Why Terraform for Infrastructure?](#why-terraform-for-infrastructure)
  - [Migration Path from Current Workflow](#migration-path-from-current-workflow)
    - [Phase 1: Replace Todoist](#phase-1-replace-todoist)
    - [Phase 2: Browser Extension](#phase-2-browser-extension)
    - [Phase 3: Full Cutover](#phase-3-full-cutover)
  - [Future-Proofing](#future-proofing)
    - [Prepared for Phase 2](#prepared-for-phase-2)
    - [Prepared for Phase 3](#prepared-for-phase-3)
    - [Prepared for Phase 4](#prepared-for-phase-4)
  - [Content Extraction: Safety \& Quality](#content-extraction-safety--quality)
    - [Security (Critical for Production)](#security-critical-for-production)
    - [Quality \& Reliability](#quality--reliability)
    - [Ethics \& Compliance](#ethics--compliance)
    - [Bookmark Model Fields](#bookmark-model-fields)
  - [Open Questions for Specification Phase](#open-questions-for-specification-phase)
  - [Success Criteria for MVP](#success-criteria-for-mvp)

## Architecture Overview

LinkRadar will be built as a **single-page application (SPA)** with a clear separation between frontend and backend:

- **Frontend**: Nuxt 4 (Vue 3 + TypeScript) running in SPA mode via Docker container with Nuxt server
- **Backend**: Rails 8.1 API-only application providing REST endpoints
- **Database**: Self-hosted PostgreSQL for all application data (including job queue, sessions via GoodJob)
- **Cache**: Redis for caching and rate limiting
- **Job Queue**: GoodJob (Postgres-backed Active Job)
- **Reverse Proxy**: Traefik for routing and SSL termination
- **Deployment**: Docker Compose orchestrating all services, Terraform for VPS infrastructure provisioning

### Component Architecture

```
User Browser
    ↓
[Traefik Reverse Proxy]
    ↓
    ├→ /api/*  → [Rails API Container]
    │              ↓
    │           [PostgreSQL]
    │              ↓
    │           [Redis]
    │              ↓
    │           [LLM API (via RubyLLM)]
    │
    └→ /*      → [Nuxt Server Container]

[Chrome Extension] → /api/* → [Rails API]
[CLI Tool (Go)]    → /api/* → [Rails API]
```

## Stack Components

### Frontend: Nuxt 4 SPA

**Framework**: Nuxt 4 in SPA mode (no SSR)
- Vue 3 with Composition API
- TypeScript for type safety
- TanStack Query for data fetching and caching
- Vue Router for client-side routing

**UI Components**: Nuxt UI 4
- Production-ready component library
- Built on Tailwind CSS primitives
- Consistent design system

**Styling**: Tailwind CSS
- Utility-first approach
- Custom design system built on Tailwind primitives
- Responsive by default

**Build**: Vite
- Fast hot module replacement during development
- Optimized production builds

**Deployment**: Docker container running Nuxt server

### Backend: Rails 8.1 API

**Framework**: Rails 8.1 (API-only mode)
- RESTful API endpoints
- Jbuilder for JSON response templates
- Strong parameters and callbacks for clean controllers
- ActiveRecord for ORM

**Authentication & Authorization**:
- **MVP**: Layered auth approach for single-user
  - **Rails API**: Single static API key (`LINKRADAR_API_KEY`) validates `Authorization: Bearer {token}` header
  - **Nuxt Frontend**: HTTP Basic Auth protects UI (`NUXT_BASIC_AUTH_USERNAME/PASSWORD`)
  - **Nuxt Server**: Proxies API requests, adds Bearer token header (never exposed to browser)
  - **CLI**: Uses Bearer token directly from environment variable
  - No user database, sessions, or CSRF needed for MVP
- **Post-MVP** (when adding multi-user support):
  - User registration and authentication system
  - Personal API tokens per user
  - OmniAuth for OAuth social login (GitHub, Google)

**Database**: PostgreSQL via ActiveRecord ORM
- Migrations for schema version control
- ActiveRecord models for data access
- ActiveRecord query interface for complex queries
- Native PostgreSQL full-text search with pg_search gem

**Content Extraction**: Layered approach for reliability
- **MetaInspector** for OpenGraph/Twitter/JSON-LD metadata extraction (title, description, images)
- **ruby-readability** for article content extraction from blog/news pages
- **Addressable::URI** for URL normalization and deduplication
- **Loofah** for HTML sanitization (XSS protection)
- **Faraday** HTTP client with timeouts, redirects, real User-Agent
- **Content Archival Strategy**: Store image URLs and raw HTML in PostgreSQL (compressed text columns), extract/render cleaned view on-demand
- Future: **Ferrum** (headless Chrome) for JS-rendered pages when needed
- Future: File storage (Shrine or similar) for downloading and archiving images locally
- Server-side execution via background job (GoodJob)

**LLM Integration**: RubyLLM
- `ruby_llm` gem - unified API for multiple LLM providers ([rubyllm.com](https://rubyllm.com/))
- Supports OpenAI, Claude, Gemini, Ollama, and more with same interface
- Synchronous tagging on capture for v1
- Response caching by URL hash to minimize costs
- Configurable model/provider selection via environment variables
- Built-in streaming, structured output, and tool calling support

**Job Queue**: GoodJob (Postgres-backed)
- Multithreaded, Postgres-based Active Job backend
- Built-in dashboard UI for job monitoring and management
- Cron-like scheduling support built-in
- Advanced features: concurrency controls, bulk enqueue, priorities
- Prepared for async tagging in future iterations
- Can run in separate worker process/container or embedded
- GitHub: [bensheldon/good_job](https://github.com/bensheldon/good_job)

**Caching**: Redis
- Fast key-value store for caching expensive operations
- Rate limiting with Rack::Attack
- Real-time features support if needed

**HTTP Client**: Faraday or HTTParty
- Fetch page content during link capture
- Configurable timeouts and retry logic

### Database: PostgreSQL

**Version**: PostgreSQL 18

**Key Features Used**:
- UUIDv7 primary keys for time-ordered, distributed-friendly IDs
- Native full-text search with GIN indexes
- JSONB columns for storing flexible metadata (tags, LLM responses)
- Partial indexes for performance

**Schema Domains**:
- Users (authentication, profiles, API tokens)
- Links (URLs, titles, captured content, archived HTML)
- Tags (user-defined and LLM-suggested)
- Link-Tag relationships (many-to-many)
- Content snapshots (archived page content)

### CLI Tool: Go

**Language**: Go 1.25+

**Features**:
- Reads `LINKRADAR_TOKEN` from environment
- Simple commands: `add`, `list`, `search`
- Structured output (JSON, table formats)
- Cross-platform single binary

**Distribution**:
- Homebrew tap for macOS/Linux
- GitHub Releases with binaries for macOS (Intel/ARM), Linux, Windows
- Built with `goreleaser` for consistent releases

### Browser Extension: Chrome (Manifest V3)

**Target**: Chrome/Chromium browsers first

**Capabilities**:
- Capture current tab URL, title, and page metadata
- Optional: highlight selected text for notes
- Quick capture with minimal UI
- Tag suggestions from recent tags

**Authentication**: Personal API token
- User copies token from web UI settings
- Stored in extension storage (encrypted by browser)

**Future**: Firefox port using WebExtensions API compatibility

## Authentication & User Flow

### MVP Auth Flow (Layered Auth)

**Frontend Layer** (Nuxt):
- HTTP Basic Auth protects Nuxt app
- Environment variables: `NUXT_BASIC_AUTH_USERNAME`, `NUXT_BASIC_AUTH_PASSWORD`
- User authenticates once to access frontend

**Backend Layer** (Rails API):
- Single static API key validation
- Environment variable: `LINKRADAR_API_KEY=supersecrettoken123`
- Validates `Authorization: Bearer {token}` header on every request

**Nuxt Server Middleware** (The Bridge):
- Proxies frontend API calls to Rails backend
- Adds `Authorization: Bearer {LINKRADAR_API_KEY}` header server-side (token never reaches browser)
- User authenticates to Nuxt, Nuxt authenticates to Rails

**CLI Usage**:
- CLI reads `LINKRADAR_API_KEY` from environment
- Sends requests directly to Rails with `Authorization: Bearer {token}` header
- No Nuxt proxy needed

**Simple, secure, zero database overhead**

### Post-MVP: Multi-User Auth (Future)

**Web App (Nuxt SPA + Rails Session Auth)**:
1. User registration and login forms
2. Can log in via email/password or GitHub/Google OAuth
3. Rails issues session cookie (database-backed via PostgreSQL)
4. Nuxt stores auth state, includes cookie in API requests

**CLI & Extension (Personal API Tokens)**:
1. User generates personal API token in web app settings
2. Token stored in environment variable or browser storage
3. Bearer token authentication

## Data Flow: Link Capture

### Via Web UI

1. User pastes URL in Nuxt form, optionally adds note/tags
2. Frontend sends POST to `/api/links`
3. Rails controller:
   - Validates request (strong parameters)
   - Creates bookmark record with pending state
   - Enqueues FetchUrlJob for background processing
   - Returns link JSON immediately
4. FetchUrlJob pipeline:
   - Fetch metadata (title, description, OG image URL) via MetaInspector
   - Extract article content via Readability
   - Normalize URL (strip tracking params, follow canonical tags, standardize)
   - Sanitize HTML content
   - Send to LLM (via RubyLLM) for tag suggestions
   - Store in Postgres (image URLs, compressed HTML in text columns)
5. Nuxt polls/subscribes for completion, displays saved link and suggestions
6. User can accept/reject/modify tags

### Via CLI

1. User runs `linkradar add https://example.com --note "Cool article" --tags biome,js`
2. CLI sends POST to `/api/links` with Bearer token
3. Same server-side flow as web UI
4. CLI displays success message

### Via Extension

1. User clicks extension icon on a page
2. Extension captures current tab URL, title, selected text
3. Sends POST to `/api/links` with Bearer token
4. Same server-side flow
5. Extension shows success notification

## Deployment Architecture

### Docker Compose Services

**Service: `app`** (Rails API)
- Ruby 3.4.x with Falcon application server
- Async/fiber-based architecture for non-blocking LLM API calls
- Directly serves Rails API with HTTP/1, HTTP/2, and TLS support
- Environment variables for DB, Redis, LLM API keys

**Service: `frontend`** (Nuxt server)
- Node.js container running Nuxt 4 in SPA mode
- Serves application via Nuxt server
- Hot reload in development, optimized builds in production

**Service: `db`** (PostgreSQL)
- PostgreSQL 18 official image
- UUIDv7 support for primary keys
- Named volume for data persistence
- Automated backups via `kartoza/pg-backup` Docker image

**Service: `redis`**
- Redis 7 official image
- Used for caching and rate limiting

**Service: `pg-backup`** (PostgreSQL Backups)
- `kartoza/pg-backup` Docker image
- Automated scheduled backups
- Configurable backup frequency and retention
- Backup files stored in persistent volume

**Service: `traefik`** (Reverse Proxy)
- Routes `/api/*` to Rails container
- Routes `/*` to Nuxt container
- Automatic SSL via Let's Encrypt
- Access logs and metrics

**Service: `worker`** (Rails job worker, optional)
- Same Rails image as `app`
- Runs `bundle exec good_job start`
- Processes background jobs when async tagging is enabled

### Infrastructure Provisioning: Terraform

**Purpose**: Automate VPS infrastructure setup and configuration

**Terraform Manages**:
- VPS instance provisioning (DigitalOcean, Linode, Hetzner, etc.)
- DNS records configuration
- Firewall rules (SSH, HTTP/HTTPS only)
- Initial server configuration (Docker installation, user setup)
- SSH key management
- Volume/block storage provisioning

**Workflow**:
1. Run `terraform apply` to provision VPS
2. Terraform outputs connection details
3. Deploy Docker Compose stack to provisioned VPS
4. Terraform state tracks infrastructure changes

**Benefits**:
- Reproducible infrastructure
- Version-controlled server configuration
- Easy disaster recovery (rebuild from code)
- Documentation as code

### Environment Configuration

Environment variables for Docker Compose:
- Database credentials
- Redis connection (required for caching and rate limiting)
- LLM API keys (OpenAI, Claude, etc. - configured via RubyLLM)
- Rails secret key base
- OAuth client IDs and secrets
- Domain names for Traefik routing
- GoodJob configuration (execution mode, max threads)

### Backup & Restore

**PostgreSQL Backups**:
- Automated via `kartoza/pg-backup` Docker container
- Scheduled dumps to persistent volume
- Configurable retention policies
- Easy restore process from backup files
- Supports off-site sync for disaster recovery

## Development Workflow

### Local Development

**Backend**: Rails with Docker Compose
- Ruby debugger for debugging
- Rails commands for migrations, seeding, testing (`rails db:migrate`, `rails db:seed`)

**Frontend**: Nuxt dev server
- Hot module replacement
- Proxies API requests to Rails container
- TypeScript checking in IDE

**Database**: Shared Postgres container
- Seeded with test data via Rails migrations and seed files

### Version Control

- **Monorepo structure**: All code (Rails API, Nuxt frontend, Go CLI, planning docs) in single repository
- GitHub for hosting
- Feature branch workflow

### CI/CD (Future)

- GitHub Actions for automated testing and builds
- Docker image builds and pushes
- Terraform plan/apply for infrastructure changes
- Automated deployment to VPS via SSH

## API Design

### REST Principles

- **API Versioning**: All routes under `/api/v1` namespace from day one
- Resource-based endpoints (`/api/v1/links`, `/api/v1/tags`)
- Standard HTTP methods (GET, POST, PUT, DELETE)
- JSON request/response bodies
- Pagination via query params (`?page=1&per_page=20`)
- Filtering via query params (`?tag=biome&search=rust`)

### Authentication

- Cookie-based for SPA
- Bearer token for CLI/extension

### Response Format

Consistent envelope structure:
- Success: `{ data: {...}, meta: {...} }`
- Error: `{ message: "...", errors: {...} }`
- Paginated: `{ data: [...], links: {...}, meta: {...} }`

### Rate Limiting

**Rack Attack** for API rate limiting:
- Redis-backed request throttling
- 60 requests/minute for authenticated users
- 10 requests/minute for unauthenticated endpoints
- IP-based throttling for abuse prevention
- Configurable per-endpoint limits

## Technology Choices: Rationale

### Why Rails?

- **20 years of experience**: Creator knows Rails inside and out - patterns, tooling, debugging
- **Proven conventions**: Convention over configuration eliminates decision fatigue
- **Mature ecosystem**: Gems for everything, battle-tested over decades
- **Developer experience**: Rails CLI, migrations, Active Record, excellent documentation
- **Rapid development**: Scaffolding, generators, and Rails Way enable fast iteration
- **Built-in features**: Authentication, CSRF protection, session management out of the box
- **Rails 8.1 modern**: Latest Rails with performance improvements and developer experience enhancements
- **API mode**: `--api` flag strips out all view/asset complexity
- **GoodJob integration**: Postgres-backed job queue fits perfectly with our database-centric architecture

### Why Falcon?

- **Async/fiber architecture**: Each request runs in a lightweight fiber, perfect for slow LLM API calls
- **Non-blocking I/O**: Upstream requests (like LLM calls) don't stall the entire server process
- **Built for modern async Ruby**: Native integration with `async`, `async-http`, and fiber-based patterns
- **HTTP/2 support**: Native HTTP/2 and TLS support out of the box
- **Better for AI workloads**: LLM API calls can take seconds - Falcon handles this gracefully while serving other requests
- **Production ready**: Used in production by real-world applications, battle-tested
- **Rack compatible**: Drop-in replacement for Puma with standard Rack interface

### Why Nuxt 4 SPA?

- **Creator familiarity**: Vue ecosystem is primary frontend skill
- **TypeScript support**: First-class TS integration
- **SPA mode**: No SSR complexity, simplified deployment
- **Composition API**: Modern, composable code patterns
- **Auto-imports**: Reduced boilerplate
- **TanStack Query**: Industry-standard data fetching with caching, background updates, optimistic updates
- **Nuxt UI 4**: Production-ready component library with beautiful, accessible components

### Why Rails Session Auth + API Tokens?

- **Simple**: Rails built-in session authentication for SPA
- **SPA-optimized**: Cookie-based auth with CSRF protection
- **Token support**: has_secure_token for CLI/extension personal API tokens
- **No extra gems needed**: Everything built into Rails

### Why Self-Hosted Postgres?

- **No lock-in**: Full control over data and schema
- **Cost predictability**: No per-GB or per-query pricing
- **Familiarity**: Creator comfortable with Postgres operations
- **Portability**: Standard SQL export/import

### Why Go for CLI?

- **Single binary**: No runtime dependencies for users
- **Cross-platform**: Compile once per OS, distribute easily
- **Fast startup**: Instant command execution
- **Strong ecosystem**: Great HTTP clients, JSON libraries

### Why Terraform for Infrastructure?

- **Infrastructure as Code**: VPS configuration lives in version control
- **Reproducible**: Destroy and rebuild infrastructure from code at any time
- **Provider agnostic**: Switch VPS providers (DigitalOcean → Hetzner) without rewriting scripts
- **State management**: Track what's deployed, plan changes before applying
- **Disaster recovery**: Complete rebuild instructions in code
- **Documentation**: Infrastructure config documents itself

## Migration Path from Current Workflow

### Phase 1: Replace Todoist

- Import existing Todoist links via CLI bulk import
- Continue using Todoist web clipper temporarily, but process links into LinkRadar via agent

### Phase 2: Browser Extension

- Replace Todoist clipper with LinkRadar extension
- Direct capture to LinkRadar database

### Phase 3: Full Cutover

- Disable Todoist workflow entirely
- All capture flows through LinkRadar UI/CLI/extension

## Future-Proofing

### Prepared for Phase 2

- GoodJob infrastructure ready for async tagging with priorities and batching
- JSONB columns for flexible LLM response storage
- Tag suggestion acceptance tracking for learning algorithms
- Redis cache structure supports trend calculation data

### Prepared for Phase 3

- API structure supports workspaces (future schema addition)
- Personal API tokens extend to team access tokens
- Postgres scales to millions of links with proper indexing
- **Authorization strategy**: Start with simple scoping, add Pundit when workspaces added (Phase 2), consider action_policy migration if context/composition becomes complex (Phase 3)

### Prepared for Phase 4

- API versioning strategy via `/api/v1/` prefixes
- Public API subset via separate route group
- MCP server can run as sidecar container reading Postgres directly

## Content Extraction: Safety & Quality

### Security (Critical for Production)
- **SSRF Protection**: Reject private/reserved IPs (10.0.0.0/8, 127.0.0.0/8, etc.)
- **URL Validation**: Only allow HTTP/HTTPS schemes
- **HTML Sanitization**: Use Loofah to strip dangerous tags/attributes before storage
- **Redirect Limits**: Max 5 hops to prevent redirect loops
- **Timeout Enforcement**: 10s connect, 15s read timeouts

### Quality & Reliability
- **URL Normalization**: 
  - Follow canonical URLs (meta/link tags)
  - Strip tracking parameters (utm_*, fbclid, etc.)
  - Normalize case and trailing slashes
- **Caching Strategy**:
  - Store raw HTML + parsed JSON
  - Respect ETag/Last-Modified headers
  - TTL: 7 days, then re-fetch on access
- **Error Handling**:
  - Exponential backoff on failures
  - Store error state for troubleshooting
  - Graceful degradation (save URL even if extraction fails)

### Ethics & Compliance
- **User-Agent**: Identify as LinkRadar bot with contact URL
- **Rate Limiting**: Per-domain throttling to be respectful
- **Robots.txt**: Honor for batch operations (not user-initiated saves)
- **Legal**: Display attribution, respect Terms of Service

### Bookmark Model Fields
```ruby
# Schema suggestion
Bookmark(
  id:              uuid     # UUIDv7 primary key (time-ordered)
  url:             string   # Normalized URL (used for display and deduplication)
  submitted_url:   string   # Original URL as submitted by user
  title:           string   # Best title (OG > HTML)
  description:     text     # Meta description
  image_url:       string   # OG/preview image URL (external)
  content_text:    text     # Plain text for full-text search
  raw_html:        text     # Compressed original HTML (can use Rails compression)
  fetch_state:     enum     # pending, success, failed
  fetch_error:     text     # Error details if failed
  fetched_at:      datetime # Last fetch timestamp
  metadata:        jsonb    # Flexible for OG/Twitter/etc.
  created_at:      datetime
  updated_at:      datetime
)
# 
# UUIDv7: Time-ordered UUIDs provide chronological ordering + distributed ID generation
# MVP: Store image URLs and compressed HTML in database
# Future: Add file storage (Shrine) to download and archive images locally
# Extract/render cleaned content on-demand from raw_html
```

## Open Questions for Specification Phase

- Should tag suggestions be stored separately from applied tags?
- How many tags per link (UI/UX constraint)?
- Personal API token expiration policy?
- Content snapshot retention policy (keep forever vs TTL)?
- Should archived HTML be compressed?
- Pagination defaults (links per page)?
- Maximum URL length?
- Duplicate URL handling (reject, or version/update existing)?
- When to trigger JS rendering (Ferrum) vs simple fetch?
- Full-text search: Monitor Postgres FTS quality, plan migration to Meilisearch if needed (Phase 3)

## Success Criteria for MVP

- **Single-user setup**: HTTP Basic Auth protects web UI, static API key for backend
- User can capture links via web UI, CLI tool, and browser extension
- CLI tool supports bulk import (for Todoist migration)
- Browser extension captures current tab with minimal UI
- LLM auto-tags every link synchronously
- User can search by tags or full-text
- User can view link archive with content preserved
- Entire stack runs on single VPS via Docker Compose
- Basic usage documentation

**Post-MVP** (not required for initial release):
- User registration and sign-up
- Personal API token management (multi-user)

---

**Next Steps**: Technical specification with database schema, API endpoints, and UI wireframes.

