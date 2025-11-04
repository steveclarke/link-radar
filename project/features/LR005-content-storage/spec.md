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
- Tracks status through 6-state lifecycle
- Stores extracted content and metadata

**FetchContentJob**:
- Triggered on ContentArchive creation
- Orchestrates content extraction pipeline
- Handles retry logic with exponential backoff

**Service Classes** (module_function pattern):
- `LinkRadar::ContentExtraction::UrlValidator` - URL validation and SSRF prevention
- `LinkRadar::ContentExtraction::HttpFetcher` - HTTP fetching with timeouts/redirects
- `LinkRadar::ContentExtraction::ContentExtractor` - Content extraction orchestration
- `LinkRadar::ContentExtraction::HtmlSanitizer` - HTML sanitization

**Configuration**:
- `ContentArchiveConfig` - Timeouts, size limits, retry settings, User-Agent

### 2.2 Processing Flow

1. Link created → ContentArchive created with `pending` status
2. FetchContentJob enqueued asynchronously
3. Pre-validation (URL scheme, private IP detection)
4. Validation fails → status to `blocked` or `invalid_url`, exit
5. Validation passes → status to `processing`, begin fetch
6. HTTP fetch → content extraction → sanitization → text extraction
7. Success → status to `success` with content stored
8. Failure → retry logic or status to `failed` with error message

### 2.3 Technology Stack

- **GoodJob** - PostgreSQL-backed Active Job backend
- **Faraday** - HTTP client with timeout/redirect support
- **ruby-readability** - Main content extraction (Mozilla Readability algorithm)
- **metainspector** - OpenGraph/Twitter Card metadata extraction
- **loofah** - HTML sanitization (XSS protection)
- **addressable** - URL normalization and validation
- **PostgreSQL** - UUIDs, enum types, jsonb columns

## 3. Data Architecture

### 3.1 Database Schema

**ContentArchive Table**:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, default: uuidv7() | Primary key |
| link_id | uuid | FK (links), NOT NULL, UNIQUE | One-to-one with Link |
| status | enum | NOT NULL, default: 'pending' | Archival state |
| error_message | text | nullable | Error details when failed |
| content_html | text | nullable | Cleaned HTML from Readability |
| content_text | text | nullable | Plain text for search |
| raw_html | text | nullable | Original HTML before processing |
| title | string(500) | nullable | Extracted page title |
| description | text | nullable | Extracted page description |
| image_url | string(2048) | nullable | Preview image URL |
| metadata | jsonb | default: {} | OpenGraph/Twitter Card data |
| fetched_at | datetime | nullable | Successful fetch timestamp |
| created_at | datetime | NOT NULL | Record creation |
| updated_at | datetime | NOT NULL | Record update |

**Indexes**:
- `content_archives.link_id` (unique)
- `content_archives.status`
- `content_archives.metadata` (GIN)
- `content_archives.content_text` (GIN, trigram) - for future full-text search

**Foreign Key**:
- `link_id` → `links.id` (cascade delete)

**Enum Type**:
```sql
CREATE TYPE content_archive_status AS ENUM (
  'pending',
  'processing', 
  'success',
  'failed',
  'invalid_url',
  'blocked'
);
```

### 3.2 Status State Machine

**States**:
- `pending` - Archive created, waiting for job
- `processing` - Job actively fetching/extracting
- `success` - Content successfully archived
- `failed` - Failed after retries exhausted
- `invalid_url` - URL validation failed (invalid scheme, malformed)
- `blocked` - URL blocked for security (private IP, SSRF)

**Transitions**:
- `pending` → `processing` | `blocked` | `invalid_url`
- `processing` → `success` | `failed` | `blocked`

### 3.3 Data Migration Strategy

**From Link Model to ContentArchive**:
- Migrate existing `content_text`, `raw_html`, `fetch_error`, `fetched_at`, `image_url`, `metadata`, `title`
- Map `link_fetch_state` enum to `content_archive_status`
- Drop migrated columns from `links` table after migration

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

### 4.1 Endpoint Changes

**No new endpoints** - archive status exposed through existing Link API responses.

### 4.2 Response Contract Enhancement

**Link Response** (`_link.json.jbuilder` modification):

Added fields when `content_archive` association exists:
- `archive_status` - Current archive status (enum string)
- `archive_fetched_at` - Timestamp of successful fetch (ISO 8601, nullable)
- `archive_error` - Error message (only when status is `failed`)

**Response Example**:
```json
{
  "id": "uuid",
  "url": "https://example.com/article",
  "title": "Example Article",
  "note": "User note",
  "tags": [...],
  "archive_status": "success",
  "archive_fetched_at": "2025-11-02T12:00:00Z"
}
```

**Response Example (failed)**:
```json
{
  "id": "uuid",
  "url": "https://example.com/article",
  "title": "Example Article",
  "note": "User note",
  "tags": [...],
  "archive_status": "failed",
  "archive_fetched_at": null,
  "archive_error": "Connection timeout after 3 attempts"
}
```

### 4.3 Future API Endpoints (Phase 2+)

Planned endpoints for when frontend UI is added:
- `GET /api/v1/links/:id/archive` - Retrieve archived content HTML
- `GET /api/v1/links/:id/archive/text` - Retrieve plain text
- `POST /api/v1/links/:id/archive/refetch` - Trigger re-fetch

## 5. Integration Architecture

### 5.1 Link Model Integration

**Association**:
- Link `has_one :content_archive, dependent: :destroy`
- ContentArchive `belongs_to :link`

**Lifecycle Hook**:
- Link `after_create` callback creates ContentArchive and enqueues FetchContentJob
- Archive record always created (even if validation fails immediately)

### 5.2 Background Job Integration

**Job Trigger**:
- Enqueued after Link creation completes
- Passes `link_id` to job for lookup
- Job updates ContentArchive status throughout pipeline

**Retry Strategy**:
- Network timeouts: Retry with exponential backoff (immediate, +2s, +4s)
- Maximum 3 attempts total
- Non-retryable errors (404, 5xx, DNS failures): Fail immediately

### 5.3 Service Class Architecture

**Stateless Utilities** (module_function pattern per codebase convention):
- UrlValidator returns validation result with reason
- HttpFetcher returns success/failure with HTML or error
- ContentExtractor returns extracted content and metadata
- HtmlSanitizer returns sanitized HTML string

**Error Handling**:
- Services return structured results (not exceptions)
- Job translates service results to ContentArchive status updates

### 5.4 External Gem Dependencies

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
│   │   └── link.rb                         # Updated with association
│   ├── jobs/
│   │   └── fetch_content_job.rb            # Background job
│   └── views/api/v1/links/
│       └── _link.json.jbuilder             # Updated response template
├── config/
│   ├── configs/
│   │   └── content_archive_config.rb       # Configuration class
│   └── content_archive.yml                 # YAML configuration
├── db/migrate/
│   ├── YYYYMMDDHHMMSS_create_content_archives.rb
│   └── YYYYMMDDHHMMSS_migrate_link_archival_data.rb
└── lib/link_radar/
    └── content_extraction/
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
- Error messages stored for debugging

**Retry Logic**:
- Network timeouts retry with exponential backoff
- Non-retryable errors fail immediately
- Maximum 3 attempts total

**Data Integrity**:
- Cascade delete ensures archive removed with link
- Unique constraint enforces one-to-one relationship
- Status transitions are atomic (single UPDATE)

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
- Service classes use module_function pattern (stateless utilities)
- Clear separation of concerns (validation, fetching, extraction, sanitization)
- Configuration centralized in ContentArchiveConfig

**Testing Strategy**:
- Manual testing for v1 (no automated tests yet)
- Test scenarios documented in requirements
- Future: Unit tests for services, integration tests for job

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
