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
- Docker (for PostgreSQL development instance)

## Getting Started

### 1. Install Dependencies

```bash
bundle install
```

### 2. Start PostgreSQL

For development, we provide a temporary PostgreSQL 18 Docker instance:

```bash
./script/dev-postgres
```

This will start PostgreSQL in the foreground with the following credentials:
- Host: `localhost`
- Port: `5432`
- User: `postgres`
- Password: `postgres`
- Database: `backend_development`

Leave this running in a terminal. Press Ctrl+C to stop.

**Note:** This is a temporary setup. Production PostgreSQL will be configured in a future work item.

### 3. Create Database

In a new terminal:

```bash
bin/rails db:create
bin/rails db:migrate
```

### 4. Start the Server

```bash
bin/rails server
```

The server will start on http://localhost:3000

### 5. Verify Health Check

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

Key configuration (to be documented as features are added):
- `DATABASE_URL` - PostgreSQL connection string (production)
- `RAILS_MASTER_KEY` - Credentials encryption key

### CORS

CORS is configured for Single Page Application (SPA) communication. See `config/initializers/cors.rb`.

## Development

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
# Run Rubocop
bin/rubocop

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
