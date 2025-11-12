# LR004 - Data Snapshot & Import System - Technical Specification

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [URL Field Simplification](#3-url-field-simplification)
4. [Data Architecture](#4-data-architecture)
5. [Export System Architecture](#5-export-system-architecture)
6. [Import System Architecture](#6-import-system-architecture)
7. [API Architecture](#7-api-architecture)
8. [Extension Integration Architecture](#8-extension-integration-architecture)
9. [File Organization](#9-file-organization)
10. [Quality Attributes](#10-quality-attributes)

---

## 1. Overview

This feature enables frictionless data export and flexible import capabilities to support fearless dogfooding and rapid schema iteration. The system provides both CLI (Rake tasks) and browser extension interfaces for exporting LinkRadar data to timestamped JSON files and importing data from LinkRadar exports or external bookmark systems.

**Key Capabilities:**
- One-click export from browser extension developer panel
- CLI export via Rake task
- File upload import from browser extension
- CLI import with flexible field mapping DSL
- Support for external bookmark systems (Notion, Raindrop, etc.)

**Related Documents:**
- Business context: [vision.md](./vision.md)
- Detailed requirements: [requirements.md](./requirements.md)
- Future enhancements: [future.md](./future.md)

---

## 2. Architecture Overview

### 2.1. System Components

The system consists of four main components:

**Export Pipeline:**
1. **Export Service** (`LinkRadar::DataExport::Exporter`) - Queries data, serializes to JSON, writes to file
2. **Export API Endpoint** (`Api::V1::DataController#export`) - Handles HTTP export requests
3. **Export Rake Task** (`linkradar:data:export`) - CLI interface

**Import Pipeline:**
1. **Import Service** (`LinkRadar::DataImport::Importer`) - Orchestrates import with transaction safety
2. **Importer DSL** (`LinkRadar::DataImport::ImporterDefinition`) - Field mapping and transformation layer
3. **Import API Endpoint** (`Api::V1::DataController#import`) - Handles HTTP import requests
4. **Import Rake Task** (`linkradar:data:import`) - CLI interface

**Shared Infrastructure:**
1. **File Management** - `data/exports/` and `data/imports/` directories (Docker volume compatible)
2. **Result Pattern** - Standardized success/failure responses using `LinkRadar::Result`

### 2.2. Core Design Decisions

**Nested JSON Format:**
- Links include embedded tag data (names + descriptions)
- Self-contained records for human readability
- Tags matched by name on import (IDs regenerated)

**Transaction Safety:**
- Entire import wrapped in single database transaction
- All-or-nothing: any error rolls back complete import
- No partial imports to maintain data integrity

**Duplicate Handling:**
- URL-based duplicate detection (normalized comparison)
- Two modes: skip (default) or update existing
- Mode selection at import time

**External System Support:**
- Ruby DSL for flexible field mapping
- Support for lambda transformations
- Reusable importer definitions per external source

---

## 3. URL Field Simplification

### 3.1. Current vs New Architecture

**Current State (Being Removed):**
- `submitted_url` - Original user input
- `url` - Normalized version

**New State (Single Field):**
- `url` - Normalized URL (only field stored)

### 3.2. Migration Strategy

**Database Changes:**
1. Remove `submitted_url` column from links table
2. Update Link model to remove `submitted_url` references
3. Update validations to only validate `url` field

**Controller Changes:**
1. LinksController accepts `url` parameter (instead of `submitted_url`)
2. Normalizes `url` before saving
3. API clients send `url` directly

**Normalization Rules:**
- Add `http://` scheme if missing
- Parse and validate URI format
- Preserve path, query, and other components

### 3.3. Migration Notes

**Data Preservation:**
- Existing `url` values already contain normalized data
- No data migration needed (just drop `submitted_url` column)
- System has no production data, safe to remove

**Rationale:**
- Simplifies mental model (one URL field)
- Original user input not needed for bookmark manager
- Reduces export/import complexity
- Aligns with YAGNI principle

---

## 4. Data Architecture

### 4.1. Database Schema

**Links Table (After URL Simplification):**
```
id              uuid            PK
url             string(2048)    NOT NULL, UNIQUE
note            text
metadata        jsonb
search_projection text
created_at      datetime        NOT NULL
updated_at      datetime        NOT NULL
```

**Tags Table:**
```
id              uuid            PK
name            string(100)     NOT NULL
slug            string(100)     NOT NULL, UNIQUE
description     string(500)
usage_count     integer         DEFAULT 0, NOT NULL
last_used_at    datetime
created_at      datetime        NOT NULL
updated_at      datetime        NOT NULL
```

**Link_Tags Join Table:**
```
id              uuid            PK
link_id         uuid            FK -> links.id
tag_id          uuid            FK -> tags.id
created_at      datetime        NOT NULL
updated_at      datetime        NOT NULL
```

### 4.2. Export Data Structure

**Format:** Nested/denormalized JSON with embedded tag data

**Schema Version:** `1.0`

**Structure:**
```json
{
  "version": "1.0",
  "exported_at": "2025-11-12T14:30:22Z",
  "metadata": {
    "link_count": 42,
    "tag_count": 15
  },
  "links": [
    {
      "url": "https://example.com/article",
      "note": "Great resource on...",
      "created_at": "2025-11-01T10:00:00Z",
      "tags": [
        {
          "name": "ruby",
          "description": "Ruby programming language"
        },
        {
          "name": "rails",
          "description": null
        }
      ]
    }
  ]
}
```

**Field Specifications:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Format version for future compatibility |
| `exported_at` | ISO8601 | Yes | Timestamp of export operation |
| `metadata.link_count` | integer | Yes | Total links in export |
| `metadata.tag_count` | integer | Yes | Unique tags across all links |
| `links` | array | Yes | Array of link objects |
| `links[].url` | string | Yes | Normalized URL |
| `links[].note` | string | No | User notes (null if empty) |
| `links[].created_at` | ISO8601 | Yes | Original creation timestamp |
| `links[].tags` | array | Yes | Array of tag objects |
| `links[].tags[].name` | string | Yes | Tag name |
| `links[].tags[].description` | string | No | Tag description (null if empty) |

**Excluded Fields:**
- Link `id` (UUIDs regenerated on import)
- Link `updated_at` (recalculated on import)
- Tag `id`, `slug`, `usage_count`, `last_used_at` (regenerated/recalculated)
- Content archives (out of scope for v1)
- Metadata jsonb field (not populated in current system)

### 4.3. Import Data Requirements

**Supported Formats:**
1. LinkRadar native format (structure above)
2. External formats via importer definitions

**Required Fields per Link:**
- `url` (string, will be normalized)
- `tags` (array, can be empty)

**Optional Fields per Link:**
- `note` (string or null)
- `created_at` (ISO8601 or null, defaults to import time if missing)

**Tag Object Requirements:**
- `name` (string, required)
- `description` (string or null, optional)

---

## 5. Export System Architecture

### 5.1. Export Service Contract

**Class:** `LinkRadar::DataExport::Exporter`

**Responsibilities:**
1. Query all links with tags for current user
2. Serialize to nested JSON format
3. Generate timestamped filename
4. Write to `data/exports/` directory
5. Return file path via Result object

**Method Signature:**
```ruby
# @return [LinkRadar::Result] Success with file path or failure with errors
def call
```

**Result Data Structure:**
```ruby
# Success case:
LinkRadar::Result.success(data: {
  file_path: "/path/to/data/exports/linkradar-export-2025-11-12-143022.json",
  link_count: 42,
  tag_count: 15
})

# Failure case:
LinkRadar::Result.failure(errors: ["Error message"])
```

### 5.2. Filename Convention

**Pattern:** `linkradar-export-YYYY-MM-DD-HHMMSS.json`

**Example:** `linkradar-export-2025-11-12-143022.json`

**Timestamp:** UTC time in ISO8601-compatible format (suitable for filenames)

### 5.3. Export Process Flow

1. Query `Link.includes(:tags).all` to eager-load associations
2. Build JSON structure with metadata and links array
3. For each link, extract URL, note, created_at, and tags
4. For each tag, extract name and description
5. Generate timestamped filename
6. Ensure `data/exports/` directory exists
7. Write JSON to file with pretty formatting
8. Return Result with file path and counts

### 5.4. Empty Export Handling

When zero links exist:
```json
{
  "version": "1.0",
  "exported_at": "2025-11-12T14:30:22Z",
  "metadata": {
    "link_count": 0,
    "tag_count": 0
  },
  "links": []
}
```

---

## 6. Import System Architecture

### 6.1. Import Service Contract

**Class:** `LinkRadar::DataImport::Importer`

**Responsibilities:**
1. Parse JSON import file
2. Validate format structure
3. Apply importer field mappings
4. Process each link within transaction
5. Handle duplicate detection and mode logic
6. Create/update links and tags
7. Return Result with import statistics

**Initialization:**
```ruby
# @param file_path [String] Full path to import file
# @param importer_name [String] Name of importer definition to use
# @param mode [Symbol] :skip or :update for duplicate handling
def initialize(file_path:, importer_name:, mode: :skip)
```

**Method Signature:**
```ruby
# @return [LinkRadar::Result] Success with stats or failure with errors
def call
```

**Result Data Structure:**
```ruby
# Success case:
LinkRadar::Result.success(data: {
  links_imported: 38,
  links_skipped: 4,
  tags_created: 12,
  tags_reused: 8
})

# Failure case:
LinkRadar::Result.failure(errors: ["Invalid JSON format", "Line 42: Invalid URL"])
```

### 6.2. Importer DSL Architecture

**Base Class:** `LinkRadar::DataImport::ImporterDefinition`

**DSL Methods:**
- `source_format(name)` - Identifies the source system
- `map(source_field, to: target_field, transform: lambda)` - Field mapping with optional transformation

**Field Mapping Contract:**
- `source_field` - Symbol representing field in source data
- `target_field` - Symbol representing Link model attribute (`:url`, `:note`, `:tags`)
- `transform` - Optional lambda/proc for data transformation

**Example Importer Definitions:**

```ruby
# lib/link_radar/importers/linkradar.rb
module LinkRadar
  module DataImport
    module Importers
      class Linkradar < ImporterDefinition
        source_format :linkradar

        map :url, to: :url
        map :note, to: :note
        map :tags, to: :tags
        map :created_at, to: :created_at
      end
    end
  end
end

# lib/link_radar/importers/notion.rb
module LinkRadar
  module DataImport
    module Importers
      class Notion < ImporterDefinition
        source_format :notion

        map :url, to: :url
        map :description, to: :note
        map :tags, to: :tags, transform: ->(tags) { tags.map { |t| { name: t.downcase } } }
      end
    end
  end
end
```

**Importer Discovery:**
- Importers located in `lib/link_radar/importers/`
- Follows Zeitwerk autoloading conventions
- Importer name maps to class name (e.g., "linkradar" → `Linkradar`)

### 6.3. Import Process Flow

**Transaction Scope:** Entire import wrapped in single transaction

**Process Steps:**
1. Parse JSON file
2. Validate basic structure (version, links array)
3. Load importer definition by name
4. Begin database transaction
5. For each link in import:
   - Apply field mappings via importer
   - Normalize URL
   - Check for duplicate by normalized URL
   - Apply duplicate handling mode (skip or update)
   - Process tags (find or create by name)
   - Create or update Link record
   - Update tag associations
6. Commit transaction
7. Return statistics

**Error Handling:**
- Any error rolls back entire transaction
- Return specific error message with context
- No partial imports

### 6.4. Duplicate Detection Logic

**Normalization Rules:**
- Parse URL with URI library
- Add `http://` if scheme missing
- Compare normalized URLs for exact match

**Skip Mode (Default):**
```ruby
if Link.exists?(url: normalized_url)
  # Increment skip counter, continue to next link
  next
end
# Create new link
```

**Update Mode:**
```ruby
link = Link.find_or_initialize_by(url: normalized_url)
if link.persisted?
  # Update all fields except created_at
  link.assign_attributes(url: normalized_url, note: note, created_at: link.created_at)
else
  # Create new link with imported created_at
  link.assign_attributes(url: normalized_url, note: note, created_at: created_at)
end
link.save!
```

### 6.5. Tag Matching and Creation

**Case-Insensitive Matching:**
```ruby
# Find existing tag by case-insensitive name comparison
existing_tag = Tag.where("LOWER(name) = ?", tag_name.downcase).first

if existing_tag
  # Use existing tag (preserves slug, usage_count, etc.)
  existing_tag
else
  # Create new tag with exact capitalization from import
  Tag.create!(name: tag_name, description: tag_description)
end
```

**Tag Association:**
- Replace link's tags array with imported tags
- Follows existing Link model `assign_tags` pattern
- Usage count incremented automatically via callbacks

---

## 7. API Architecture

### 7.1. API Endpoints

**Base Path:** `/api/v1/data`

**Endpoints:**
1. `POST /api/v1/data/export` - Export all links
2. `POST /api/v1/data/import` - Import links from uploaded file

### 7.2. Export Endpoint Contract

**Route:** `POST /api/v1/data/export`

**Authentication:** Required (Bearer token)

**Request:** No body required

**Response Structure:**

Success (200 OK):
```json
{
  "data": {
    "file_path": "linkradar-export-2025-11-12-143022.json",
    "link_count": 42,
    "tag_count": 15,
    "download_url": "/api/v1/data/exports/linkradar-export-2025-11-12-143022.json"
  }
}
```

Error (500 Internal Server Error):
```json
{
  "error": "Export failed: [error details]"
}
```

**File Download:**
- Export creates file in `data/exports/`
- Response includes download URL
- Separate GET endpoint serves the file: `GET /api/v1/data/exports/:filename`

### 7.3. Import Endpoint Contract

**Route:** `POST /api/v1/data/import`

**Authentication:** Required (Bearer token)

**Request Content-Type:** `multipart/form-data`

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | file | Yes | JSON file to import |
| `importer` | string | No | Importer name (defaults to "linkradar") |
| `mode` | string | No | "skip" or "update" (defaults to "skip") |

**Response Structure:**

Success (200 OK):
```json
{
  "data": {
    "links_imported": 38,
    "links_skipped": 4,
    "tags_created": 12,
    "tags_reused": 8
  }
}
```

Error (422 Unprocessable Entity):
```json
{
  "error": "Import failed: Invalid JSON format"
}
```

Error (400 Bad Request):
```json
{
  "error": "No file provided"
}
```

### 7.4. Data Controller Structure

**File:** `app/controllers/api/v1/data_controller.rb`

**Actions:**
- `export` - Calls Exporter service, returns result
- `import` - Receives file upload, calls Importer service, returns result
- `download` - Serves export file for download (static file serving)

**Permitted Parameters:**
```ruby
def import_params
  params.permit(:file, :importer, :mode)
end
```

---

## 8. Extension Integration Architecture

### 8.1. Developer Panel Integration

**Location:** Extension options page, developer mode section

**Access:** Toggle "Developer Mode" switch in settings header

**UI Components:**
1. Export button - "Export All Links"
2. Import file picker with mode dropdown
3. Toast notifications for feedback

### 8.2. TypeScript Type Definitions

**File:** `extension/lib/types/dataExport.ts`

```typescript
/**
 * Export operation result from backend
 */
export interface ExportResult {
  file_path: string
  link_count: number
  tag_count: number
  download_url: string
}

/**
 * Backend API response for export
 */
export interface ExportApiResponse {
  data: ExportResult
}

/**
 * Import operation result from backend
 */
export interface ImportResult {
  links_imported: number
  links_skipped: number
  tags_created: number
  tags_reused: number
}

/**
 * Backend API response for import
 */
export interface ImportApiResponse {
  data: ImportResult
}

/**
 * Import mode options
 */
export type ImportMode = 'skip' | 'update'
```

### 8.3. API Client Methods

**File:** `extension/lib/apiClient.ts`

```typescript
/**
 * Export all links to JSON file
 * @returns Export result with download URL
 */
export async function exportLinks(): Promise<ExportResult>

/**
 * Import links from uploaded file
 * @param file - JSON file to import
 * @param importer - Importer name (defaults to "linkradar")
 * @param mode - Import mode: skip or update (defaults to "skip")
 * @returns Import statistics
 */
export async function importLinks(
  file: File,
  importer: string = 'linkradar',
  mode: ImportMode = 'skip'
): Promise<ImportResult>
```

### 8.4. UI Component Structure

**Component:** `extension/entrypoints/options/components/DataManagementSection.vue`

**Component Responsibilities:**
1. Display export button
2. Handle export click → call API → trigger browser download
3. Display import file picker and mode dropdown
4. Handle file selection → call API → show results
5. Show toast notifications for success/error feedback

**User Flow - Export:**
1. User clicks "Export All Links"
2. Component calls `exportLinks()` API method
3. Backend generates file, returns download URL
4. Component triggers browser download
5. Toast shows "Exported 42 links"

**User Flow - Import:**
1. User selects mode from dropdown ("Skip duplicates" default)
2. User selects file from file picker
3. Component calls `importLinks(file, 'linkradar', mode)`
4. Backend processes import
5. Toast shows "Imported 38 links, 12 new tags"

---

## 9. File Organization

### 9.1. Backend File Structure

```
backend/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           └── data_controller.rb          # Export/import endpoints
│   └── models/
│       ├── link.rb                             # Updated: remove submitted_url
│       └── tag.rb                              # Unchanged
├── lib/
│   ├── link_radar/
│   │   ├── data_export/
│   │   │   └── exporter.rb                     # Export service
│   │   └── data_import/
│   │       ├── importer.rb                     # Import service
│   │       ├── importer_definition.rb          # DSL base class
│   │       └── importers/
│   │           ├── linkradar.rb                # Native format importer
│   │           └── notion.rb                   # Example external importer
│   └── tasks/
│       └── data.rake                           # Rake tasks (export/import)
└── db/
    └── migrate/
        └── YYYYMMDDHHMMSS_remove_submitted_url_from_links.rb
```

### 9.2. Extension File Structure

```
extension/
├── lib/
│   ├── apiClient.ts                            # Add exportLinks/importLinks methods
│   └── types/
│       └── dataExport.ts                       # Export/import type definitions
└── entrypoints/
    └── options/
        └── components/
            └── DataManagementSection.vue       # New component
```

### 9.3. Data Directories

```
data/
├── exports/                                    # Export files written here
│   └── linkradar-export-*.json                # Timestamped exports
└── imports/                                    # Import files placed here (CLI default)
    └── *.json                                 # Import source files
```

**Docker Volume Mapping:**
- `data/` directory mapped as Docker volume
- Persists across container restarts
- Accessible from both Rails app and host system

---

## 10. Quality Attributes

### 10.1. Reliability

**Transaction Safety:**
- All imports wrapped in single database transaction
- Rollback on any error
- No partial imports

**File Operations:**
- Ensure directory exists before write
- Handle file system errors gracefully
- Return clear error messages

**Empty State Handling:**
- Export succeeds with empty links array
- Import succeeds with empty file (no-op)

### 10.2. Data Integrity

**URL Normalization:**
- Consistent normalization rules
- Duplicate detection via normalized comparison
- Validation via URI parsing

**Tag Matching:**
- Case-insensitive name matching
- Preserves existing tag data (slug, usage_count)
- Creates new tags with exact capitalization

**Timestamp Preservation:**
- Export preserves original `created_at`
- Import uses imported `created_at` when present
- Update mode preserves original `created_at`

### 10.3. Usability

**CLI Interface:**
```bash
# Export
rake linkradar:data:export

# Import with defaults (skip mode, linkradar format)
rake linkradar:data:import[filename.json]

# Import with full options
rake linkradar:data:import[filename.json,notion,update]
```

**Extension Interface:**
- One-click export (no configuration)
- Simple file picker for import
- Mode selection dropdown with clear labels
- Toast notifications with meaningful counts

**Error Messages:**
- Specific error context (e.g., "Line 42: Invalid URL")
- Actionable feedback
- No technical jargon in extension UI

### 10.4. Extensibility

**Importer DSL:**
- Simple to add new external system importers
- Reusable definitions in predictable location
- Support for common transformations

**Format Versioning:**
- Export includes `version` field
- Future formats can add new fields
- Backward compatibility considerations for v2+

**Future Extensions (Out of Scope v1):**
- Snapshot management UI
- Validation/preview before import
- Compression support
- Multiple export formats
- Filtering/selective export

### 10.5. Performance

**No specific targets for v1** - optimized for solo developer use case

**Expected Performance:**
- Export 1000 links: < 2 seconds
- Import 1000 links: < 10 seconds (includes tag matching)
- File size: ~1KB per link (rough estimate)

**Scalability Considerations (Future):**
- Eager loading prevents N+1 queries
- Transaction overhead acceptable for personal use
- Batch processing not needed for solo developer dataset

### 10.6. Security

**Authentication:**
- All API endpoints require Bearer token authentication
- Standard Rails CSRF protection

**File Access:**
- File operations restricted to `data/` directory
- No arbitrary file system access
- Downloads served through controller (not static files)

**Input Validation:**
- JSON structure validation
- URL validation via URI parsing
- ActiveRecord validations enforce database constraints

---

## Appendix A: Migration Checklist

**URL Simplification Tasks:**
- [ ] Create migration to drop `submitted_url` column
- [ ] Update Link model: remove `submitted_url` validation
- [ ] Update LinksController: change param from `submitted_url` to `url`
- [ ] Update API client: send `url` instead of `submitted_url`
- [ ] Update extension types: remove `submitted_url` from Link interface
- [ ] Run migration in development
- [ ] Test link creation flow end-to-end

**Implementation Order:**
1. URL simplification (foundation)
2. Export service and rake task
3. Export API endpoint
4. Import service, DSL, and rake task
5. Import API endpoint
6. Extension UI integration
7. End-to-end testing

