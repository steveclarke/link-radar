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
- `bin/services --auto-ports` or `-a` - Auto-discover and use available ports
- `bin/services down` - Stop all services
- `bin/services logs -f` - Follow logs in real-time
- `bin/services --help` - See all available options

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
- `bin/dev --auto-port` or `-a` - Auto-discover and assign available port
- `bin/dev --bind 127.0.0.1` or `-b 127.0.0.1` - Bind to a specific address
- `bin/dev --help` - See all available options

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

# Auto-discover and use available ports
bin/services --auto-ports

# Combine auto-ports with daemon mode
bin/services -a -d

# Stop all services
bin/services down

# View logs
bin/services logs

# Follow logs in real-time
bin/services logs -f
```

**Port Conflict Resolution:**

If you encounter port conflicts (e.g., another app using PostgreSQL on 5432), use the `--auto-ports` flag:

```bash
bin/services --auto-ports
```

This will:
- Automatically find available ports for all services
- Update your `.env` file with the discovered ports
- Remember these ports for future runs

This is especially useful when:
- Running multiple projects that use the same default ports
- Working with git worktrees (each worktree can have unique ports)
- Port 5432, 6379, 1080, or 1025 are already in use

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
