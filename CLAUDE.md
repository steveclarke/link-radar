# Monorepo structure

- `backend/` — Rails 8.1 API (Ruby 3.4.x, PostgreSQL 18). Run commands from this directory.
- `extension/` — Chrome extension (Vue 3, WXT, TypeScript, Tailwind CSS 4). pnpm workspace package.
- `project/` — Planning docs and work items (not code).
- `deploy/` — Kamal deployment config.

# Backend (Rails)

Run all backend commands from `backend/`:

```sh
bin/services          # Start Docker services (Postgres, Redis, MailDev)
bin/dev               # Setup + start Rails dev server
bin/rspec             # Run tests (RSpec)
bin/standardrb        # Lint (StandardRB); --fix to auto-fix
bin/brakeman          # Security scan
bin/ci                # Full CI suite (lint + security + tests)
```

- Ruby style: StandardRB with standard-rails plugin. No custom rules beyond `.standard.yml`.
- Tests: RSpec with FactoryBot, Shoulda Matchers, WebMock, SimpleCov.
- UUIDv7 primary keys on all tables.
- Background jobs: GoodJob (Postgres-backed).
- State machines: Statesman gem (not AASM).
- LLM integration: RubyLLM gem (`ruby_llm`), not direct API calls.
- API auth: Bearer token via `X-Api-Key` header.
- All API routes namespaced under `/api/v1/`.
- Pagination: Pagy gem.
- Search: pg_search (PostgreSQL full-text).

# Extension (Chrome)

Run from `extension/`:

```sh
pnpm dev              # Dev mode with hot reload
pnpm build            # Production build
pnpm lint             # ESLint; lint:fix to auto-fix
```

- Built with WXT framework. Entrypoints in `entrypoints/`.
- ESLint config: @antfu/eslint-config.

# Deployment

Production deployed via Kamal to `prime.clevertakes.com`. Secrets from 1Password.

```sh
kamal deploy -d production    # Deploy (run from backend/)
```
