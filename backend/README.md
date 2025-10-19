# LinkRadar Backend

Rails 8.1 API backend for LinkRadar - a personal knowledge radar for capturing and discovering trends in your learning.

## Tech Stack

- **Rails 8.1** (API-only mode)
- **Ruby 3.4.x** (managed via mise)
- **PostgreSQL 18** with UUIDv7 primary keys
- **Falcon** application server (planned)
- **Rack Attack** for rate limiting (planned)

## Prerequisites

- Ruby 3.4.x (managed via mise)
- Docker and Docker Compose (for backend services)
- Rails credentials master key (stored in 1Password under the `link-radar` vault)

## Getting Started

### Quick Start

The easiest way to get the backend running is to use our automated setup scripts:

#### 1. Prepare Your Master Key

Before running setup, have your `config/master.key` ready. This is used to decrypt Rails credentials. 

**Note:** The Rails master key is stored in 1Password under the `link-radar` vault.

#### 2. Start Backend Services

In one terminal, start the Docker Compose services (PostgreSQL, Redis, etc.):

```bash
bin/services
```

This will start all backend services in the foreground. Leave this running. Press Ctrl+C to stop all services.

The services include:
- **PostgreSQL 18** on `localhost:5432`
- Additional services will be added here as the project grows

#### 3. Run Setup

In a new terminal, run the setup script:

```bash
bin/setup
```

This will:
- Check that PostgreSQL is running
- Install Ruby dependencies
- Copy `.env.sample` to `.env` (if needed)
- Prompt for your `master.key` (if not present)
- Install system dependencies (libvips, ffmpeg) on first run
- Set up and prepare the database
- Start the Rails development server

**Options:**
- `bin/setup --reset` - Reset the database before starting
- `bin/setup --skip-server` - Set up without starting the server

#### 4. Verify Health Check

Once the server is running (http://localhost:3000 by default):

```bash
curl http://localhost:3000/up
```

You should see a green HTML page indicating the system is healthy.

**Note:** If port 3000 is already in use, set `PORT=3001` (or any available port) in your `.env` file.

### Manual Setup (Advanced)

If you prefer manual control or need to troubleshoot:

1. Start services: `bin/services`
2. Install dependencies: `bundle install`
3. Set up database: `bin/rails db:prepare`
4. Start server: `bin/dev`

## API Structure

All API routes are namespaced under `/api/v1/` (to be configured).

Example endpoints (coming soon):
- `GET /api/v1/links` - List saved links
- `POST /api/v1/links` - Create a new link
- `GET /api/v1/tags` - List tags

## Configuration

### Environment Variables

Key configuration (to be documented as features are added):
- `DATABASE_URL` - PostgreSQL connection string (production)
- `RAILS_MASTER_KEY` - Credentials encryption key

### CORS

CORS is configured for Single Page Application (SPA) communication. See `config/initializers/cors.rb`.

## Development

### Backend Services

Manage all Docker Compose services (PostgreSQL, Redis, etc.):

```bash
# Start all services (foreground)
bin/services

# Start in detached mode (background)
bin/services up -d

# Stop all services
bin/services down

# View logs
bin/services logs

# Restart a specific service
bin/services restart postgres
```

See `bin/services --help` for more options.

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
