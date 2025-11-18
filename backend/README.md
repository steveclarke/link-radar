# LinkRadar Backend

Rails 8.1 API backend for LinkRadar - a personal knowledge radar for capturing and discovering trends in your learning.

## Table of Contents

- [LinkRadar Backend](#linkradar-backend)
  - [Table of Contents](#table-of-contents)
  - [Tech Stack](#tech-stack)
  - [Prerequisites](#prerequisites)
  - [Getting Started](#getting-started)
    - [Quick Start](#quick-start)
      - [1. Credentials Setup](#1-credentials-setup)
      - [2. Start Backend Services](#2-start-backend-services)
      - [3. Start Development Server](#3-start-development-server)
      - [4. Verify Health Check](#4-verify-health-check)
  - [API Structure](#api-structure)
  - [Configuration](#configuration)
    - [Environment Variables](#environment-variables)
    - [CORS](#cors)
    - [1Password CLI Integration](#1password-cli-integration)
  - [Development](#development)
    - [Setup](#setup)
    - [Backend Services](#backend-services)
    - [Rails Console](#rails-console)
    - [Database Operations](#database-operations)
    - [Code Quality](#code-quality)
    - [API Testing with Bruno](#api-testing-with-bruno)
    - [Data Export \& Import](#data-export--import)
      - [CLI Usage](#cli-usage)
      - [Import Modes](#import-modes)
      - [Reserved Tags](#reserved-tags)
      - [API Endpoints](#api-endpoints)
      - [Data Format](#data-format)
      - [Docker Volume Mapping](#docker-volume-mapping)
      - [Automated Cleanup](#automated-cleanup)
  - [Project Status](#project-status)
  - [Documentation](#documentation)
    - [Backend Guides](#backend-guides)

## Tech Stack

- **Rails 8.1** (API-only mode)
- **Ruby 3.4.x** (managed via mise)
- **PostgreSQL 18** with UUIDv7 primary keys
- **Falcon** application server (planned)
- **Rack Attack** for rate limiting (planned)

## Prerequisites

- Ruby 3.4.x (managed via mise)
- Docker and Docker Compose (for backend services)
- Rails credentials master key (see [Credentials Setup](#credentials-setup) below)

## Getting Started

### Quick Start

The easiest way to get the backend running is to use our automated scripts:

#### 1. Credentials Setup

The setup script automatically retrieves your Rails `master.key` in priority order:

1. **1Password CLI** (recommended) - Automatic fetch with biometric prompt
2. **`RAILS_MASTER_KEY` env var** - Set in shell environment/profile
3. **Manual entry** - Prompts if neither above is available

**Quick setup for 1Password CLI:**
```bash
brew install 1password-cli
# Enable in: 1Password app → Settings → Developer → Integrate with 1Password CLI
op signin
op whoami  # Verify (prompts for biometric auth)
```

See the [1Password CLI Guide](../project/guides/backend/1password-cli-guide.md) for full setup and usage details.

#### 2. Start Backend Services

In one terminal, start the Docker Compose services (PostgreSQL, Redis, etc.):

```bash
bin/services
```

This will start all backend services in the foreground. Leave this running. Press Ctrl+C to stop all services.

The services include:
- **PostgreSQL 18** on `localhost:5432`
- **Redis 7** on `localhost:6379`
- **MailDev** on `localhost:1080` (web) and `localhost:1025` (SMTP)

**Options:**
- `bin/services -d` - Start in detached mode (background)
- `bin/services down` - Stop all services
- `bin/services logs -f` - Follow logs in real-time
- `bin/services --help` - See all available options

**Port Conflicts:**
If you encounter port conflicts (another app using the default ports), run:
```bash
bin/configure-ports
```

This interactive tool will show you which ports are in use and help you configure available alternatives.

#### 3. Start Development Server

In a new terminal, run:

```bash
bin/dev
```

This single command will:
- Check that PostgreSQL is running
- Run the idempotent setup (dependencies, database, etc.)
- Fetch your `master.key` from 1Password CLI (if not present)
- Start the Rails development server

**Options:**
- `bin/dev --skip-setup` or `-s` - Start server without running setup first
- `bin/dev --debug` or `-d` - Start with rdbg debugger
- `bin/dev --port 3001` or `-p 3001` - Start on a specific port
- `bin/dev --bind 127.0.0.1` or `-b 127.0.0.1` - Bind to a specific address
- `bin/dev --help` - See all available options

If port 3000 is in use, run `bin/configure-ports` to find an available port.

#### 4. Verify Health Check

Once the server is running (http://localhost:3000 by default):

```bash
curl http://localhost:3000/up
```

You should see a green HTML page indicating the system is healthy.

## API Structure

All API routes are namespaced under `/api/v1/` (to be configured).

Example endpoints (coming soon):
- `GET /api/v1/links` - List saved links
- `POST /api/v1/links` - Create a new link
- `GET /api/v1/tags` - List tags

## Configuration

### Environment Variables

Key configuration:
- `PORT` - Rails server port (default: 3000)
- `POSTGRES_PORT` - PostgreSQL port (default: 5432)
- `REDIS_PORT` - Redis port (default: 6379)
- `MAILDEV_WEB_PORT` - MailDev web UI port (default: 1080)
- `MAILDEV_SMTP_PORT` - MailDev SMTP port (default: 1025)

**LLM Configuration:**
- `OPENAI_API_KEY` - OpenAI API key for AI-powered features (required for link analysis)
- `LLM_ANALYSIS_MODEL` - Model to use for link analysis (default: `gpt-4o-mini`)
- `LLM_MAX_TAGS_FOR_ANALYSIS` - Maximum tags to send for AI context (default: 5000)

> **Note:** LLM models are automatically loaded during `bin/setup`. If models are missing from the database, run `bin/rails ruby_llm:load_models` manually.

**Rails Credentials:**
- `RAILS_MASTER_KEY` - Can be set in shell environment as fallback if not using 1Password CLI

**1Password Configuration (optional):**
- `SKIP_ONEPASSWORD` - Set to `true` to skip 1Password CLI integration (for developers without 1Password)
- `MASTER_KEY_OP_ITEM_ID` - 1Password item ID for master.key (defaults to LinkRadar project item)
- `MASTER_KEY_OP_VAULT` - 1Password vault name (default: `LinkRadar`)
- `MASTER_KEY_OP_FIELD` - 1Password field name (default: `credential`)

### CORS

CORS is configured for Single Page Application (SPA) communication. See `config/initializers/cors.rb`.

### 1Password CLI Integration

For complete documentation on using 1Password CLI for secret management, see the [1Password CLI Guide](../project/guides/backend/1password-cli-guide.md).

## Development

### Setup

Run the idempotent setup script to update dependencies and database:

```bash
# Run setup
bin/setup

# Reset database during setup
bin/setup --reset
```

The setup script is idempotent and safe to run at any time. It's automatically run by `bin/dev` unless you use `--skip-setup`.

### Backend Services

Manage all Docker Compose services (PostgreSQL, Redis, MailDev):

```bash
# Start all services (foreground)
bin/services

# Start in detached mode (background)
bin/services -d

# Stop all services
bin/services down

# View logs
bin/services logs

# Follow logs in real-time
bin/services logs -f
```

**Port Configuration:**

All service ports can be configured via the `.env` file:
- `POSTGRES_PORT` (default: 5432)
- `REDIS_PORT` (default: 6379)
- `MAILDEV_WEB_PORT` (default: 1080)
- `MAILDEV_SMTP_PORT` (default: 1025)

**Handling Port Conflicts:**

If you encounter port conflicts (e.g., another app using PostgreSQL on 5432), use the interactive port configuration tool:

```bash
bin/configure-ports
```

This tool will:
- Show your current port configuration and which ports are in use
- Suggest available alternative ports
- Optionally update your `.env` file with the new ports (with confirmation)

This is especially useful when:
- Running multiple projects that use the same default ports
- Working with git worktrees (each worktree can have unique ports)
- Any default ports (5432, 6379, 1080, 1025, 3000) are already in use

See `bin/services --help` for all options.

### Rails Console

```bash
bin/rails console
```

### Database Operations

```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed database
bin/rails db:seed

# Reset database
bin/rails db:reset
```

### Code Quality

```bash
# Run StandardRB linter
bin/standardrb

# Fix StandardRB issues automatically
bin/standardrb --fix

# Run Brakeman security scan
bin/brakeman

# Run CI suite locally
bin/ci
```

### API Testing with Bruno

The project uses [Bruno](https://www.usebruno.com/) for API testing. API request collections are located in the `bruno/` directory.

**Environment Setup:**

The `bin/setup` script automatically creates `bruno/.env` from `bruno/.env.example` if it doesn't exist. To customize your local port, edit `bruno/.env`:

```bash
# Rails server port (should match RAILS_PORT in backend .env)
RAILS_PORT=3000

# API Key for development
API_KEY=dev_api_key_change_in_production
```

Bruno automatically reads variables from the `.env` file and makes them available via `process.env`. The environment files reference these variables:

```2:3:backend/bruno/environments/Local.bru
  baseUrl: http://localhost:{{process.env.RAILS_PORT}}
  apiKey: {{process.env.API_KEY}}
```

**Note:** The `.env` file is gitignored so each developer can configure their own local port. This is especially useful when using `bin/configure-ports` which may suggest different ports on different machines.

**Available Collections:**
- `bruno/Links/` - Link management endpoints
- `bruno/Tags/` - Tag management endpoints

**Learn more:** [Bruno DotEnv Documentation](https://docs.usebruno.com/secrets-management/dotenv-file)

### Data Export & Import

LinkRadar provides export and import capabilities for backing up data during development and migrating bookmarks from external systems.

**Operations are synchronous** - Export and import run in the request/response cycle with immediate feedback. This is appropriate for current scale (single user, operations complete in <30 seconds). If operations exceed 30-60 seconds or multi-user concurrent usage becomes common, these can be migrated to background jobs with polling endpoints.

#### CLI Usage

**Export all links:**

```bash
bin/rake snapshot:export
```

Creates timestamped JSON file in `snapshot/exports/` directory. Links tagged with `~temp~` are excluded.

**Import from file:**

```bash
# Import with skip mode (default - skip duplicates)
bin/rake snapshot:import[filename.json]

# Import with update mode (overwrite existing links)
bin/rake snapshot:import[filename.json,update]
```

Files in `snapshot/imports/` can be referenced by filename only. Full paths also supported.

#### Import Modes

- **Skip mode (default)**: Ignore duplicate URLs, preserve existing data
- **Update mode**: Overwrite existing links completely (except `created_at` timestamp)

Duplicates detected by normalized URL comparison.

#### Reserved Tags

Links tagged with `~temp~` are excluded from all exports. Use this for testing in production without polluting backups.

#### API Endpoints

**Export:**
```
POST /api/v1/snapshot/export
Authorization: Bearer <token>

Response:
{
  "data": {
    "file_path": "linkradar-export-2025-11-12-143022-uuid.json",
    "link_count": 42,
    "tag_count": 15,
    "download_url": "/api/v1/snapshot/exports/linkradar-export-2025-11-12-143022-uuid.json"
  }
}
```

**Download:**
```
GET /api/v1/snapshot/exports/:filename
Authorization: Bearer <token>
```

**Import:**
```
POST /api/v1/snapshot/import
Authorization: Bearer <token>
Content-Type: multipart/form-data

Parameters:
- file: JSON file (LinkRadar format)
- mode: "skip" or "update" (optional, defaults to "skip")

Response:
{
  "data": {
    "links_imported": 38,
    "links_skipped": 4,
    "tags_created": 12,
    "tags_reused": 8
  }
}
```

#### Data Format

Export files use nested/denormalized JSON format:

```json
{
  "version": "1.0",
  "exported_at": "2025-11-12T14:30:22Z",
  "metadata": {
    "link_count": 2,
    "tag_count": 2
  },
  "links": [
    {
      "url": "https://example.com",
      "note": "Example site",
      "created_at": "2025-11-01T10:00:00Z",
      "tags": [
        {"name": "ruby", "description": "Ruby programming language"},
        {"name": "rails", "description": null}
      ]
    }
  ]
}
```

Tags matched by name (case-insensitive) on import. IDs regenerated.

#### Docker Volume Mapping

`snapshot/` directory is mapped as Docker volume for persistence. Export/import files accessible from both container and host system.

#### Automated Cleanup

Snapshot files are automatically cleaned up daily at 2:00 AM:

- Exports: Deleted after 30 days (`SNAPSHOT_EXPORTS_RETENTION_DAYS`)
- Imports: Deleted after 30 days (`SNAPSHOT_IMPORTS_RETENTION_DAYS`)
- Temp: Deleted after 7 days (`SNAPSHOT_TMP_RETENTION_DAYS`)

Manual cleanup:

```bash
bin/rails runner 'CleanupSnapshotsJob.perform_now'
```

## Project Status

🚧 **Currently in development** - Core infrastructure setup (LR001)

See the [main project README](../README.md) for overall project status and roadmap.

## Documentation

- [Main Project README](../README.md)
- [Vision Document](../project/vision.md)
- [Work Items](../project/work-items/)

### Backend Guides

- [1Password CLI Guide](../project/guides/backend/1password-cli-guide.md) - Secret management with biometric auth
- [Configuration Management Guide](../project/guides/backend/configuration-management-guide.md)
