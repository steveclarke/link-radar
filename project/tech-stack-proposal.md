# LinkRadar - Technology Stack Proposal

**Approach:** Laravel API + Nuxt SPA  
**Target:** 4-week MVP for self-hosted deployment

## Architecture Overview

LinkRadar will be built as a **single-page application (SPA)** with a clear separation between frontend and backend:

- **Frontend**: Nuxt 3 (Vue 3 + TypeScript) running in SPA mode, served as static assets
- **Backend**: Laravel 11 API-only application providing REST endpoints
- **Database**: Self-hosted PostgreSQL for all application data
- **Cache/Queue**: Redis for session storage, caching, and future job queues
- **Reverse Proxy**: Traefik for routing and SSL termination
- **Deployment**: Docker Compose orchestrating all services on a single VPS

### Component Architecture

```
User Browser
    ↓
[Traefik Reverse Proxy]
    ↓
    ├→ /api/*  → [Laravel API Container]
    │              ↓
    │           [PostgreSQL]
    │              ↓
    │           [Redis]
    │              ↓
    │           [OpenAI API]
    │
    └→ /*      → [Nuxt SPA Static Assets]

[Chrome Extension] → /api/* → [Laravel API]
[CLI Tool (Go)]    → /api/* → [Laravel API]
```

## Stack Components

### Frontend: Nuxt 3 SPA

**Framework**: Nuxt 3 in SPA mode (no SSR)
- Vue 3 with Composition API
- TypeScript for type safety
- Pinia for state management
- Vue Router for client-side routing

**Styling**: Tailwind CSS
- Utility-first approach
- Custom design system built on Tailwind primitives
- Responsive by default

**Build**: Vite
- Fast hot module replacement during development
- Optimized production builds
- Static asset generation

**Deployment**: Served as static files from Traefik or dedicated nginx container

### Backend: Laravel 11 API

**Framework**: Laravel 11 (API-only configuration)
- RESTful API endpoints
- API resource transformers for consistent response shapes
- Route model binding and form requests for clean controllers

**Authentication & Authorization**:
- **Laravel Sanctum** for SPA authentication and personal API tokens
  - Cookie-based session auth for the Nuxt frontend (stateful)
  - Bearer token auth for CLI and browser extension (stateless)
  - Built-in CSRF protection for SPA
- **Laravel Socialite** for OAuth social login
  - GitHub provider
  - Google provider
  - Extensible for additional providers

**Database**: PostgreSQL via Laravel Eloquent ORM
- Migrations for schema version control
- Eloquent models for data access
- Query builder for complex queries
- Native PostgreSQL full-text search via Laravel Scout database driver

**Content Extraction**: PHP Readability library
- `andreskrey/readability.php` for extracting main content from HTML
- Falls back to raw HTML storage if extraction fails
- Server-side execution on link capture

**LLM Integration**: OpenAI PHP Client
- `openai-php/client` package for API communication
- Synchronous tagging on capture for v1
- Response caching by URL hash to minimize costs
- Configurable model selection via environment variables

**Job Queue**: Redis-backed queues (future-ready)
- Laravel Horizon for queue monitoring
- Prepared for async tagging in future iterations
- Separate worker container for job processing

**Caching**: Redis
- Response caching for expensive operations
- Session storage
- Rate limiting

**HTTP Client**: Guzzle (Laravel default)
- Fetch page content during link capture
- Configurable timeouts and retry logic

### Database: PostgreSQL

**Version**: PostgreSQL 15+

**Key Features Used**:
- Native full-text search with GIN indexes
- JSONB columns for storing flexible metadata (tags, LLM responses)
- UUID primary keys for distributed-friendly IDs
- Partial indexes for performance

**Schema Domains**:
- Users (authentication, profiles, API tokens)
- Links (URLs, titles, captured content, archived HTML)
- Tags (user-defined and LLM-suggested)
- Link-Tag relationships (many-to-many)
- Content snapshots (archived page content)

### CLI Tool: Go

**Language**: Go 1.21+

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

### Web App (Nuxt SPA + Sanctum)

1. User visits app, lands on login page
2. Can log in via:
   - Email/password (stored in database)
   - GitHub OAuth (via Socialite)
   - Google OAuth (via Socialite)
3. Laravel Sanctum issues session cookie
4. Nuxt stores auth state, includes cookie in API requests
5. Laravel validates session on each request

### CLI & Extension (Personal API Tokens)

1. User generates personal API token in web app settings
2. Token stored in:
   - CLI: environment variable `LINKRADAR_TOKEN`
   - Extension: browser storage
3. Each request includes token in `Authorization: Bearer {token}` header
4. Laravel Sanctum validates token and identifies user

## Data Flow: Link Capture

### Via Web UI

1. User pastes URL in Nuxt form, optionally adds note/tags
2. Frontend sends POST to `/api/links`
3. Laravel controller:
   - Validates request
   - Fetches page HTML via HTTP client
   - Extracts main content using Readability
   - Sends content to OpenAI for tag suggestions
   - Stores link, content snapshot, and tags in Postgres
   - Returns link resource with suggested tags
4. Nuxt displays saved link and suggestions
5. User can accept/reject/modify tags

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

**Service: `app`** (Laravel API)
- PHP 8.2 with FPM
- Nginx serving Laravel public directory
- Environment variables for DB, Redis, OpenAI API key
- Volume for storage/logs

**Service: `frontend`** (Nuxt static assets)
- Nginx serving built SPA
- Pre-built during CI or locally before deploy

**Service: `db`** (PostgreSQL)
- Postgres 15 official image
- Named volume for data persistence
- Backup strategy via pg_dump cron

**Service: `redis`**
- Redis 7 official image
- Used for cache, sessions, queues

**Service: `traefik`** (Reverse Proxy)
- Routes `/api/*` to Laravel container
- Routes `/*` to Nuxt container
- Automatic SSL via Let's Encrypt
- Access logs and metrics

**Service: `worker`** (Laravel queue worker, future)
- Same Laravel image as `app`
- Runs `php artisan queue:work`
- Processes background jobs when async tagging is enabled

### Environment Configuration

Single `.env` file for Docker Compose:
- Database credentials
- Redis connection
- OpenAI API key
- Laravel app key
- OAuth client IDs and secrets
- Domain names for Traefik routing

### Backup & Restore

- PostgreSQL: Daily pg_dump to volume, sync to off-site storage
- Redis: RDB snapshots for cache recovery (non-critical)
- File storage: Content snapshots stored in Postgres (no separate file storage)

## Development Workflow

### Local Development

**Backend**: Laravel Sail or custom Docker Compose
- Hot reload via file watching
- Xdebug for debugging
- Artisan commands for migrations, seeding, testing

**Frontend**: Nuxt dev server
- Hot module replacement
- Proxies API requests to Laravel container
- TypeScript checking in IDE

**Database**: Shared Postgres container
- Seeded with test data via Laravel migrations and seeders

### Version Control

- Separate Git repositories or monorepo (decision pending)
- GitHub for hosting
- Feature branch workflow

### CI/CD (Future)

- GitHub Actions for automated testing and builds
- Docker image builds and pushes
- Automated deployment to VPS via SSH

## API Design

### REST Principles

- Resource-based endpoints (`/api/links`, `/api/tags`)
- Standard HTTP methods (GET, POST, PUT, DELETE)
- JSON request/response bodies
- Pagination via query params (`?page=1&per_page=20`)
- Filtering via query params (`?tag=biome&search=rust`)

### Authentication

- Cookie-based for SPA (Sanctum)
- Bearer token for CLI/extension (Sanctum)

### Response Format

Consistent envelope structure:
- Success: `{ data: {...}, meta: {...} }`
- Error: `{ message: "...", errors: {...} }`
- Paginated: `{ data: [...], links: {...}, meta: {...} }`

### Rate Limiting

Laravel's built-in rate limiting:
- 60 requests/minute for authenticated users
- 10 requests/minute for unauthenticated endpoints

## Technology Choices: Rationale

### Why Laravel?

- **Turnkey auth**: Sanctum + Socialite = SPA + OAuth + API tokens with minimal configuration
- **Mature ecosystem**: Extensive packages for common needs
- **Developer experience**: Artisan CLI, migrations, seeders, excellent documentation
- **Rails-like conventions**: Familiar mental model for creator
- **Queue system ready**: Built-in Redis-backed queues for future async work
- **Strong typing**: PHP 8.2+ with strict types and static analysis via PHPStan

### Why Nuxt 3 SPA?

- **Creator familiarity**: Vue ecosystem is primary frontend skill
- **TypeScript support**: First-class TS integration
- **SPA mode**: No SSR complexity, just static assets
- **Composition API**: Modern, composable code patterns
- **Auto-imports**: Reduced boilerplate

### Why Sanctum over Passport?

- **Simpler**: No OAuth2 server complexity for personal use
- **SPA-optimized**: Cookie-based auth designed for first-party SPAs
- **Token support**: Personal API tokens for CLI/extension
- **Lightweight**: Fewer dependencies and concepts

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

- Queue infrastructure ready for async tagging
- JSONB columns for flexible LLM response storage
- Tag suggestion acceptance tracking for learning algorithms
- Redis cache structure supports trend calculation data

### Prepared for Phase 3

- API structure supports workspaces (future schema addition)
- Personal API tokens extend to team access tokens
- Postgres scales to millions of links with proper indexing

### Prepared for Phase 4

- API versioning strategy via `/api/v1/` prefixes
- Public API subset via separate route group
- MCP server can run as sidecar container reading Postgres directly

## Open Questions for Specification Phase

- Should tag suggestions be stored separately from applied tags?
- How many tags per link (UI/UX constraint)?
- Personal API token expiration policy?
- Content snapshot retention policy (keep forever vs TTL)?
- Should archived HTML be compressed?
- Pagination defaults (links per page)?
- Maximum URL length?
- Duplicate URL handling (reject, or version/update existing)?

## Success Criteria for MVP

- User can sign up via email or GitHub
- User can capture links via web UI, CLI, and extension
- LLM auto-tags every link synchronously
- User can search by tags or full-text
- User can view link archive with content preserved
- User can manage personal API tokens
- Entire stack runs on single VPS via Docker Compose
- Basic usage docs for all capture methods

---

**Next Steps**: Technical specification with database schema, API endpoints, and UI wireframes.

