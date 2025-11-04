# LR005 - Content Archival & Storage: Technical Specification

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Data Architecture](#3-data-architecture)
4. [API Architecture](#4-api-architecture)
5. [Integration Architecture](#5-integration-architecture)
6. [Configuration Architecture](#6-configuration-architecture)
7. [File Organization](#7-file-organization)
8. [Quality Attributes](#8-quality-attributes)

## 1. Overview

Automatically capture and preserve web page content when links are saved to LinkRadar. Backend-only implementation (v1) - no frontend UI.

**Key Design Principles**:
- Best effort, graceful degradation - failures never block link creation
- Server-side extraction for consistency and security
- Separate ContentArchive model from Link model
- Asynchronous background processing

## 2. Architecture Overview

### 2.1 Core Components

**ContentArchive Model**:
- One-to-one with Link (cascade delete)
- Tracks status through 6-state lifecycle using Statesman state machine
- Stores extracted content and metadata
- Full transition history for audit trail and debugging

**ArchiveContentJob**:
- Triggered on ContentArchive creation
- Orchestrates content extraction pipeline
- Handles retry logic with exponential backoff

**Service Classes** (using Result pattern):
- `LinkRadar::ContentArchiving::UrlValidator` - URL validation and SSRF prevention
- `LinkRadar::ContentArchiving::HttpFetcher` - HTTP fetching with timeouts/redirects
- `LinkRadar::ContentArchiving::ContentExtractor` - Content extraction orchestration
- `LinkRadar::ContentArchiving::HtmlSanitizer` - HTML sanitization

**Configuration**:
- `ContentArchiveConfig` - Timeouts, size limits, retry settings, User-Agent

### 2.2 Processing Flow

1. Link created → ContentArchive created with `pending` status
2. ArchiveContentJob enqueued asynchronously (no validation at this point)
3. **Job starts**: Pre-validation (URL scheme, private IP detection)
4. Validation fails → status to `blocked` or `invalid_url`, exit
5. Validation passes → status to `processing`, begin fetch
6. HTTP fetch → content extraction → sanitization → text extraction
7. Success → status to `success` with content stored
8. Failure → retry logic or status to `failed` with error message

**Design Note**: All validation happens inside the job (step 3+), not before enqueueing. This keeps link creation fast since URL validation requires DNS resolution (network call) for private IP detection. Jobs that fail validation immediately are minimal overhead, and this approach keeps all archival logic centralized in one place.

### 2.3 Technology Stack

- **GoodJob** - PostgreSQL-backed Active Job backend
- **Statesman** - State machine for tracking archival status with full transition history
- **Faraday** - HTTP client with timeout/redirect support
- **ruby-readability** - Main content extraction (Mozilla Readability algorithm)
- **metainspector** - OpenGraph/Twitter Card metadata extraction
- **loofah** - HTML sanitization (XSS protection)
- **addressable** - URL normalization and validation
- **PostgreSQL** - UUIDs, jsonb columns, efficient state queries

## 3. Data Architecture

### 3.1 Database Schema

**ContentArchive Table**:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, default: uuidv7() | Primary key |
| link_id | uuid | FK (links), NOT NULL, UNIQUE | One-to-one with Link |
| error_message | text | nullable | Error details when failed |
| content_html | text | nullable | Cleaned HTML from Readability |
| content_text | text | nullable | Plain text for search |
| title | string(500) | nullable | Extracted page title |
| description | text | nullable | Extracted page description |
| image_url | string(2048) | nullable | Preview image URL |
| metadata | jsonb | default: {} | OpenGraph/Twitter Card data |
| fetched_at | datetime | nullable | Successful fetch timestamp |
| created_at | datetime | NOT NULL | Record creation |
| updated_at | datetime | NOT NULL | Record update |

**Note**: Status is managed by Statesman state machine, not stored on this model.

**Indexes**:
- `content_archives.link_id` (unique) - Enforces one-to-one relationship with Link. Used for lookups when displaying link details with archive status.
- `content_archives.metadata` (GIN) - Enables efficient querying of JSONB metadata fields (OpenGraph/Twitter Card data). Future use for filtering by metadata attributes.
- `content_archives.content_text` (GIN, trigram) - Enables full-text search across archived content. Not used in v1 but prepared for future search features.

**Foreign Key**:
- `link_id` → `links.id` (cascade delete)

**ContentArchiveTransition Table** (Statesman):

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK, auto-increment | Primary key |
| content_archive_id | uuid | FK, NOT NULL, indexed | Foreign key to content_archives |
| to_state | string | NOT NULL, indexed | Target state |
| metadata | jsonb | default: {} | Transition context (error details, duration, etc.) |
| sort_key | integer | NOT NULL, indexed | Transition ordering |
| most_recent | boolean | NOT NULL, indexed | Current state flag |
| created_at | datetime | NOT NULL | Transition timestamp |
| updated_at | datetime | NOT NULL | Record update |

**Indexes**:
- `content_archive_transitions.content_archive_id` - Join to parent record
- `content_archive_transitions.to_state` - Query by state (e.g., find all failed archives)
- `content_archive_transitions.sort_key` - Order transitions chronologically
- `content_archive_transitions.most_recent` - Efficiently find current state
- Composite: `(content_archive_id, most_recent)` - Optimized current state lookup per Statesman docs

**Foreign Key**:
- `content_archive_id` → `content_archives.id` (cascade delete)

### 3.2 Status State Machine (Statesman)

**States**:
- `pending` (initial) - Archive created, waiting for job
- `processing` - Job actively fetching/extracting
- `success` - Content successfully archived
- `failed` - Failed after retries exhausted
- `invalid_url` - URL validation failed (invalid scheme, malformed)
- `blocked` - URL blocked for security (private IP, SSRF)

**Allowed Transitions**:
- `pending` → `processing` | `blocked` | `invalid_url`
- `processing` → `success` | `failed` | `blocked`

**State Machine Class**: `ContentArchiveStateMachine`
- Location: `app/state_machines/content_archive_state_machine.rb`
- Includes `Statesman::Machine`
- Defines states, transitions, and optional guards/callbacks

**Transition Metadata** (stored in `content_archive_transitions.metadata` jsonb):
- `error_message` (string) - Error details for failed transitions
- `validation_reason` (string) - Why URL was blocked/invalid
- `fetch_duration_ms` (integer) - Time taken for successful fetches
- `retry_count` (integer) - Current retry attempt number
- `http_status` (integer) - HTTP response code if applicable

**Usage**:
```ruby
# Check current state (using delegate method)
archive.current_state  # => "pending"

# Transition with metadata (using delegate method)
archive.transition_to!(:processing)
archive.transition_to!(:success, { fetch_duration_ms: 1234 })
archive.transition_to!(:failed, { error_message: "Timeout", retry_count: 3 })

# Check allowed transitions (using delegate method)
archive.allowed_transitions  # => ["processing", "blocked", "invalid_url"]
archive.can_transition_to?(:processing)  # => true

# Query by state (via Statesman queries - class level)
ContentArchive.in_state(:pending)
ContentArchive.in_state(:failed)
```

### 3.3 Data Migration Strategy

**No data migration needed** - The Link model's content-related fields (`content_text`, `fetch_error`, `fetched_at`, `image_url`, `metadata`, `title`, `raw_html`) are currently unused and empty.

**Migration steps**:
1. Create ContentArchive model and content_archive_transitions table
2. Drop unused content-related columns from `links` table in the same migration
3. All new archives will start fresh with `pending` status

### 3.4 Metadata Structure

**JSONB Schema** (`content_archives.metadata`):
```json
{
  "opengraph": {
    "title": "string",
    "description": "string",
    "image": "string",
    "type": "string",
    "url": "string"
  },
  "twitter": {
    "card": "string",
    "title": "string",
    "description": "string",
    "image": "string"
  },
  "canonical_url": "string"
}
```

## 4. API Architecture

### 4.1 V1 API Changes

**No API changes in v1** - Content archival happens silently in the background. Archive data is stored in the database but not exposed through API responses.

**Link Response**: Unchanged. No archive-related fields added.

### 4.2 Future API Changes (Phase 2+)

**Link Response Enhancement** - When archive UI is added, include archive fields in `_link.json.jbuilder`:
- `archive_status` - Current archive status (enum string)
- `archive_fetched_at` - Timestamp of successful fetch (ISO 8601, nullable)
- `archive_error` - Error message (only when status is `failed`)

## 5. Integration Architecture

### 5.1 Link Model Integration

**Association**:
- Link `has_one :content_archive, dependent: :destroy`
- ContentArchive `belongs_to :link`

**Lifecycle Hook**:
- Link `after_create` callback creates ContentArchive and enqueues ArchiveContentJob
- Archive record always created (even if validation fails immediately)

### 5.2 Background Job Integration

**Job Trigger**:
- Enqueued immediately after Link creation completes (no pre-validation)
- Passes `link_id` to job for lookup
- Job performs all validation, fetching, and extraction
- Job uses state machine to transition between states with metadata

**Job and State Machine Interaction**:
- Job calls `archive.transition_to!(:state, metadata)` at each step (using delegate method)
- Metadata captures context: error messages, fetch duration, retry count, etc.
- State machine enforces valid transitions (guards prevent invalid state changes)
- Transition history provides full audit trail for debugging

**Retry Strategy**:
- Network timeouts: Retry with exponential backoff (immediate, +2s, +4s)
- Maximum 3 attempts total
- Non-retryable errors (404, 5xx, DNS failures): Fail immediately

### 5.3 Service Class Architecture

**Service Classes** (Result pattern with `LinkRadar::Resultable`):
- All services include `LinkRadar::Resultable` for consistent return values
- Each service is instantiated with required parameters, then `call` is invoked
- Services return `LinkRadar::Result` objects with `success?`, `failure?`, `data`, and `errors`
- Example: `result = UrlValidator.new(url).call`

**Service Responsibilities**:
- `UrlValidator` - Returns success with validated URL or failure with reason
- `HttpFetcher` - Returns success with HTML content or failure with error
- `ContentExtractor` - Returns success with extracted content/metadata or failure with error
- `HtmlSanitizer` - Returns success with sanitized HTML or failure with error

**Error Handling**:
- Services return Result objects (not exceptions)
- Job checks `result.success?` and transitions state machine accordingly
- Failure reasons stored in transition metadata for debugging

### 5.4 State Machine Setup

**Generator Command**:
```bash
rails generate link_radar:state_machine ContentArchive pending:initial processing success failed invalid_url blocked
```

**What the Generator Creates**:
- `app/state_machines/content_archive_state_machine.rb` - State machine definition
- `app/models/content_archive_transition.rb` - Transition model
- Migration for `content_archive_transitions` table
- Factory and RSpec tests (if applicable)

**Model Integration** (already handled by generator):
- Adds `has_many :content_archive_transitions, dependent: :destroy`
- Adds `include Statesman::Adapters::ActiveRecordQueries`
- Adds `state_machine` method returning state machine instance
- Delegate methods: `current_state`, `can_transition_to?`, `transition_to!`, `allowed_transitions`

**Customize Transitions**: After generation, edit the state machine to define allowed transitions:
```ruby
# app/state_machines/content_archive_state_machine.rb
transition from: :pending, to: [:processing, :blocked, :invalid_url]
transition from: :processing, to: [:success, :failed, :blocked]
```

### 5.5 External Gem Dependencies

**Required Gems** (add to Gemfile):
- `metainspector` - OpenGraph/Twitter Card metadata extraction
- `ruby-readability` - Main content extraction
- `loofah` - HTML sanitization
- `faraday` - HTTP client
- `addressable` - URL parsing and normalization

**Note**: ruby-readability cannot inline images to base64 data URIs (images remain as external URLs in v1).

## 6. Configuration Architecture

### 6.1 ContentArchiveConfig

**Configuration Class** (Anyway Config pattern):

| Setting | Default | Type | Description |
|---------|---------|------|-------------|
| connect_timeout | 10 | integer | HTTP connect timeout (seconds) |
| read_timeout | 15 | integer | HTTP read timeout (seconds) |
| max_redirects | 5 | integer | Maximum redirect hops |
| max_file_size | 10485760 | integer | Maximum file size (10MB in bytes) |
| max_retries | 3 | integer | Total retry attempts |
| retry_backoff_base | 2 | integer | Backoff base (seconds) |
| user_agent_contact_url | (required) | string | Contact URL for User-Agent header |
| enabled | true | boolean | Global enable/disable |

**Configuration Sources** (priority order):
1. Environment variables (e.g., `CONTENT_ARCHIVE_CONNECT_TIMEOUT`)
2. YAML file (`config/content_archive.yml`)
3. Rails credentials (`content_archive.connect_timeout`)
4. Code defaults

### 6.2 User-Agent Format

Format: `LinkRadar/1.0 (+{contact_url})`

Example: `LinkRadar/1.0 (+https://linkradar.example.com/contact)`

## 7. File Organization

```
backend/
├── app/
│   ├── models/
│   │   ├── content_archive.rb              # ContentArchive model
│   │   ├── content_archive_transition.rb   # Statesman transition model
│   │   └── link.rb                         # Updated with association
│   ├── state_machines/
│   │   └── content_archive_state_machine.rb # Statesman state machine
│   └── jobs/
│       └── archive_content_job.rb          # Background job
├── config/
│   ├── configs/
│   │   └── content_archive_config.rb       # Configuration class
│   └── content_archive.yml                 # YAML configuration
├── db/migrate/
│   ├── YYYYMMDDHHMMSS_create_content_archives.rb
│   ├── YYYYMMDDHHMMSS_create_content_archive_transitions.rb
│   └── YYYYMMDDHHMMSS_migrate_link_archival_data.rb
└── lib/link_radar/
    ├── result.rb                           # Result class for success/failure
    ├── resultable.rb                       # Resultable concern
    └── content_archiving/
        ├── url_validator.rb                # SSRF prevention
        ├── http_fetcher.rb                 # HTTP fetching
        ├── content_extractor.rb            # Content extraction
        └── html_sanitizer.rb               # HTML sanitization
```

## 8. Quality Attributes

### 8.1 Security

**SSRF Prevention**:
- Block private IP ranges: 10.0.0.0/8, 127.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12, 169.254.0.0/16
- Validate resolved IP addresses before HTTP requests
- Only allow HTTP/HTTPS schemes

**Content Security**:
- Sanitize HTML to remove scripts, event handlers, XSS vectors
- Store only sanitized content in database

**Network Security**:
- Enforce timeout limits to prevent hung connections
- Limit file sizes to prevent resource exhaustion
- Limit redirect chains to prevent redirect loops

### 8.2 Reliability

**Failure Isolation**:
- Archival failures never prevent link creation
- Archive record always created (even on immediate failure)
- Error messages stored in transition metadata for debugging

**Retry Logic**:
- Network timeouts retry with exponential backoff
- Non-retryable errors fail immediately
- Maximum 3 attempts total
- Each retry tracked in transition metadata

**Data Integrity**:
- Cascade delete ensures archive and transitions removed with link
- Unique constraint enforces one-to-one Link-ContentArchive relationship
- State transitions are atomic (single INSERT into transitions table)
- Statesman ensures transition history is never lost

### 8.3 Performance

**For v1**:
- No specific performance requirements
- Background processing prevents user-facing impact
- Processing speed depends on external sites
- Single-user scale (no optimization needed)

**Future Considerations**:
- PostgreSQL full-text search index ready for Phase 2
- GIN indexes support efficient jsonb querying
- Trigram index supports fuzzy text search

### 8.4 Maintainability

**Code Organization**:
- Service classes use Result pattern with `LinkRadar::Resultable`
- State machine provides clear visibility into archival workflow
- Clear separation of concerns (validation, fetching, extraction, sanitization)
- Configuration centralized in ContentArchiveConfig
- Transition history provides audit trail for debugging

**Testing Strategy**:
- Manual testing for v1 (no automated tests yet)
- Test scenarios documented in requirements
- Future: Unit tests for services, integration tests for job, state machine specs

### 8.5 Scalability

**For v1**:
- Single-user personal use
- Default GoodJob configuration sufficient
- No concurrency limits needed

**Future Scalability**:
- GoodJob supports concurrency controls when needed
- Background processing scales independently
- Database indexes support efficient querying as archives grow

---

**References**:
- Vision: [vision.md](vision.md)
- Requirements: [requirements.md](requirements.md)
- Future Enhancements: [future.md](future.md)
