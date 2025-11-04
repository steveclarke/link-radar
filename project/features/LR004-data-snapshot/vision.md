# LR004 - Data Snapshot & Import System

**Vision:** Enable fearless dogfooding and rapid schema iteration through frictionless data export and flexible import capabilities.

## Table of Contents

- [LR004 - Data Snapshot \& Import System](#lr004---data-snapshot--import-system)
  - [Table of Contents](#table-of-contents)
  - [Problem](#problem)
  - [Solution](#solution)
    - [Data Format Philosophy](#data-format-philosophy)
    - [Import DSL Philosophy](#import-dsl-philosophy)
  - [User Needs](#user-needs)
  - [Future Possibilities](#future-possibilities)
  - [Scope](#scope)
    - [What's IN v1](#whats-in-v1)
    - [What's NOT in v1](#whats-not-in-v1)

## Problem

LinkRadar is ready for active dogfooding, but there's a critical blocker: no safety net for data during rapid development. The schema will evolve quickly as features are built, and currently there's no convenient way to protect accumulated bookmarks during these iterations.

**The friction today:**
- Must manually write custom export scripts each time experimentation is needed
- No quick way to snapshot data before schema changes
- Tedious to migrate data after rearchitecture
- Existing bookmarks in Notion and other systems require manual migration scripts
- This friction makes it feel risky to start actively using LinkRadar

**The consequence:** Development is blocked from dogfooding the system, which means missing critical real-world feedback and delaying the value of having a working bookmark manager.

**Note:** This isn't about disaster recovery (pg_dump handles that). This is about **development velocity** - removing the friction that blocks rapid experimentation.

## Solution

Build a simple, developer-friendly snapshot system with two core principles:

**1. Frictionless Export**
One-click export from the browser extension's developer mode panel, plus a CLI rake task for terminal workflows. Exports produce timestamped JSON files in a nested, human-readable format that preserves all tag relationships.

**2. Flexible Import**
File upload in the extension for production convenience, plus a lightweight Ruby DSL that makes field mapping elegant and reusable. Write an importer once (`importers/notion.rb`, `importers/raindrop.rb`), use it anytime you need to bring data from that source.

**Key differentiator:** This isn't just "write export scripts anyway" - it's about removing the context-switch cost. Click a button, get your data. Write a simple DSL mapping, import from anywhere.

### Data Format Philosophy

**Nested/denormalized JSON:**
```json
{
  "exported_at": "2025-11-03T14:30:22Z",
  "version": "1.0",
  "links": [
    {
      "url": "https://example.com",
      "title": "Example Article",
      "notes": "Great resource on...",
      "tags": ["ruby", "rails", "tutorial"],
      "created_at": "2025-11-01T10:00:00Z"
    }
  ]
}
```

**Why nested over flat?**
- Human-readable - easy to review and manually edit
- Self-contained - each link is complete
- Natural fit for importing from external systems (Notion, Raindrop export this way)
- Tag relationships preserved by name (IDs can change, radar still works)

### Import DSL Philosophy

Simple, Ruby-native field mapping that handles schema evolution gracefully:

```ruby
# importers/notion.rb
LinkRadar::Importer.define do
  source_format :notion
  
  map :url, to: :url
  map :title, to: :title
  map :description, to: :notes
  map :tags, to: :tags, transform: ->(tags) { tags.map(&:downcase) }
end
```

Write importers for each external source, or adjust mappings when your schema changes.

## User Needs

**Developer (dogfooding LinkRadar):**
- Safely experiment with schema changes without fear of data loss
- Quickly migrate data after rearchitecture
- Import existing bookmarks from Notion, Raindrop, Obsidian with minimal friction
- Have confidence to start actively using LinkRadar for real bookmarks
- Avoid context-switching to "write export scripts" mode

## Future Possibilities

Phase 2 and beyond could include compression, snapshot management UI, automatic backups before migrations, validation/preview, rollback mechanisms, incremental exports, and more.

See [future.md](./future.md) for detailed future enhancements.

## Scope

### What's IN v1

**Export Capabilities:**
- Button in extension's developer mode panel → downloads timestamped JSON file
- Rake task for CLI export: `rake linkradar:export`
- Nested/denormalized JSON format (human-readable, preserves tag relationships)
- Timestamped filenames: `linkradar-export-2025-11-03-143022.json`
- Metadata in export: version, timestamp, record counts

**Import Capabilities:**
- File upload in extension's developer mode panel → imports JSON with mode selection (skip/update)
- Rake task with DSL: `rake linkradar:import[file.json,importer,mode]` (mode: skip or update, defaults to skip)
- Lightweight Ruby DSL for field mapping
- Base importer class with transformation support
- Example importers included: `importers/linkradar.rb` (own format), `importers/notion.rb` (external)
- Import creates/finds tags by name (IDs can change, relationships preserved)
- Basic error handling and validation

**Core Behaviors:**
- Tags matched case-insensitively by name (preserves radar co-occurrence data)
- Import mode selection: additive (default) or overwrite
- Duplicate detection by URL with configurable strategy:
  - **Skip mode**: Ignore duplicates, keep existing data (safe default)
  - **Update mode**: Overwrite existing links with imported data (useful for corrections/migrations)

### What's NOT in v1

**Explicitly deferred to Phase 2+:**
- Snapshot management UI (list, delete old snapshots)
- Automatic backups before migrations
- Validation/preview before import
- Rollback mechanism
- Content archival export (feature doesn't exist yet)
- Compression/zip files
- Multiple export formats
- Scheduled/automatic exports
- Incremental exports (only changes)
- Export filtering (by tags, date ranges)
- Advanced merging strategies (merge/combine fields, conflict resolution rules beyond skip/update)
- Cloud backup integration

**Rationale for scope:**
This is a solo developer tool focused on removing friction. The goal is confidence to start dogfooding, not production-grade backup infrastructure. pg_dump already handles disaster recovery - this is about development velocity.

