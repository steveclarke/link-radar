# LR004 - Data Snapshot & Import System - Future Enhancements

This document outlines potential enhancements beyond v1 scope. These are not committed features, just documented possibilities to revisit as needs evolve.

## Phase 2: Enhanced Import/Export

### Compression & Large Datasets
**When:** Content archival feature ships, exports could get large
- Gzip compression for exports
- Automatic compression for exports over certain size
- Zip archives when including content files
- Streaming import for large files

### Validation & Safety
**When:** Moving beyond solo developer to shared usage
- Preview import before applying (show what will be created/updated)
- Dry-run mode for imports
- Validation errors with detailed messages
- Import summary report (X links created, Y tags matched, Z errors)

### Duplicate Handling Strategies
**When:** Need to re-import or merge datasets
- Configurable duplicate handling: skip, update, create-new
- Smart merge (update notes but preserve existing tags)
- Conflict resolution UI
- Import diff view (what changed)

### Rollback Mechanism
**When:** Imports go wrong and need undo
- Automatic snapshot before import
- One-click rollback to pre-import state
- Import transaction log
- Selective undo (only certain records)

## Phase 3: Automation & Management

### Snapshot Management UI
**When:** Accumulating many snapshots, need organization
- List all snapshots with metadata (size, date, record count)
- Delete old snapshots
- Compare two snapshots (diff view)
- Tag/label snapshots ("before-schema-v2", "notion-import-2025")
- Storage usage tracking

### Automatic Snapshots
**When:** Want protection without manual action
- Scheduled automatic exports (daily, weekly)
- Pre-migration hooks (auto-snapshot before rake db:migrate)
- Retention policy (keep last N snapshots)
- Storage quota management

### Incremental Exports
**When:** Full exports become too large/slow
- Export only changes since last export
- Delta format with base reference
- Incremental import (apply deltas)
- Snapshot chain management

## Phase 4: Advanced Features

### Export Filtering & Selection
**When:** Need targeted exports for specific use cases
- Filter by tags: `rake linkradar:export[tags=ruby,rails]`
- Filter by date range: `--since=2025-01-01`
- Filter by modified date
- Export specific links by ID
- Save filter presets

### Multiple Export Formats
**When:** Integration with other tools needed
- CSV export (spreadsheet-friendly)
- Markdown export (one file per link)
- HTML export (browseable archive)
- OPML export (RSS reader import)
- Browser bookmarks format (Chrome, Firefox)

### Cloud Backup Integration
**When:** Want off-site backups without manual downloads
- Automatic upload to S3/Backblaze/Dropbox
- Encrypted cloud backups
- Scheduled cloud sync
- Restore from cloud UI

### Advanced Import DSL
**When:** Complex import scenarios emerge
- Conditional mappings (if-then logic)
- Nested data transformations
- Lookup tables for mapping values
- Multi-pass imports (resolve dependencies)
- Import plugins/extensions

### Content Migration Support
**When:** Content archival feature exists
- Export includes archived page content
- Import handles content files
- Content deduplication
- Binary attachment support
- Content transformation (format conversions)

## Phase 5: Multi-User Considerations

### User Isolation
**When:** LinkRadar supports multiple users
- Per-user exports
- Workspace/team exports
- Permission checks on import
- Audit trail for imports

### Collaborative Features
**When:** Teams share bookmark collections
- Export sharing (generate shareable link)
- Import from team member's export
- Merge strategies for conflicting data
- Change tracking and attribution

## Strategic Future Vision

### Migration as First-Class Feature
Eventually, snapshot/import could become the primary mechanism for:
- Local development → staging → production promotion
- Testing schema changes safely
- Sharing curated bookmark collections
- Onboarding new users with starter collections
- Platform migrations (move LinkRadar to new infrastructure)

### Data Portability Philosophy
Long-term goal: Your data should never be trapped in LinkRadar. The export format should be:
- Simple enough to parse without special tools
- Complete enough to reconstruct full state
- Documented enough that other tools can consume it
- Standard enough to integrate with broader ecosystems (ActivityPub, etc.)

## Non-Goals (Probably Never)

**Real-time sync:**
- This isn't Dropbox - snapshot/import is deliberate, not automatic
- If real-time sync is needed, that's a different feature entirely

**Version control integration (Git):**
- JSON diffs in Git are messy for large datasets
- Better to use snapshots as checkpoints, not track every change
- If granular history is needed, that's application-level audit logs

**Database replication:**
- Use PostgreSQL's built-in replication for that
- This feature is about data portability, not high-availability

---

**Note:** This document will evolve as usage patterns emerge. The solo-developer use case drives v1; future phases will be informed by actual needs discovered during dogfooding.

