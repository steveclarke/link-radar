# LR004 - Data Snapshot & Import System - Requirements

## Table of Contents

- [LR004 - Data Snapshot \& Import System - Requirements](#lr004---data-snapshot--import-system---requirements)
  - [Table of Contents](#table-of-contents)
  - [1. User Stories \& Business Needs](#1-user-stories--business-needs)
    - [1.1. Developer (Dogfooding LinkRadar)](#11-developer-dogfooding-linkradar)
  - [2. Core System Capabilities](#2-core-system-capabilities)
    - [2.1. Export Capabilities](#21-export-capabilities)
    - [2.2. Import Capabilities](#22-import-capabilities)
    - [2.3. Data Management Interface](#23-data-management-interface)
  - [3. Business Data Requirements](#3-business-data-requirements)
    - [3.1. Export Data Structure](#31-export-data-structure)
    - [3.2. Import Field Mapping](#32-import-field-mapping)
    - [3.3. Tag Data](#33-tag-data)
  - [4. Business Rules \& Logic](#4-business-rules--logic)
    - [4.1. Export Rules](#41-export-rules)
    - [4.2. Import Rules](#42-import-rules)
    - [4.3. Duplicate Detection](#43-duplicate-detection)
    - [4.4. Tag Matching and Creation](#44-tag-matching-and-creation)
    - [4.5. Timestamp Preservation](#45-timestamp-preservation)
    - [4.6. Import Modes](#46-import-modes)
  - [5. User Experience Requirements](#5-user-experience-requirements)
    - [5.1. Extension Interface](#51-extension-interface)
    - [5.2. Feedback and Notifications](#52-feedback-and-notifications)
    - [5.3. Error Handling](#53-error-handling)
  - [6. Quality Attributes \& Constraints](#6-quality-attributes--constraints)
    - [6.1. Reliability](#61-reliability)
    - [6.2. Data Integrity](#62-data-integrity)
    - [6.3. Usability](#63-usability)
    - [6.4. Performance](#64-performance)
    - [6.5. Security](#65-security)
  - [7. Integration Touchpoints](#7-integration-touchpoints)
    - [7.1. Browser Extension Integration](#71-browser-extension-integration)
    - [7.2. Backend API Integration](#72-backend-api-integration)
    - [7.3. File System Integration](#73-file-system-integration)
    - [7.4. External System Compatibility](#74-external-system-compatibility)
  - [8. Development \& Testing Approach](#8-development--testing-approach)
    - [8.1. Development Strategy](#81-development-strategy)
    - [8.2. Testing Strategy](#82-testing-strategy)
  - [9. Success Criteria](#9-success-criteria)
    - [9.1. Acceptance Criteria](#91-acceptance-criteria)
    - [9.2. Definition of Success](#92-definition-of-success)
  - [10. Constraints \& Assumptions](#10-constraints--assumptions)
    - [10.1. Scope Boundaries](#101-scope-boundaries)
    - [10.2. Assumptions](#102-assumptions)

## 1. User Stories & Business Needs

### 1.1. Developer (Dogfooding LinkRadar)

**As a developer dogfooding LinkRadar, I need to:**

- **Safely experiment with schema changes** without fear of data loss, so I can iterate rapidly during development
- **Quickly export my data before making database changes**, so I have a safety net for schema migrations
- **Import data back after schema changes**, so I can restore my bookmarks after database rearchitecture
- **Migrate existing bookmarks from external systems** (Notion, Raindrop, Obsidian) with minimal friction, so I can consolidate my bookmarks in LinkRadar
- **Avoid context-switching to "write export scripts" mode**, so I can stay focused on feature development
- **Have confidence to actively use LinkRadar for real bookmarks**, knowing my data is safe and portable

**Business Context:**

See [vision.md](./vision.md) for the strategic context. This feature removes the critical blocker preventing active dogfooding by providing a safety net during rapid development and schema iteration.

## 2. Core System Capabilities

### 2.1. Export Capabilities

The system must provide the ability to export all link data to a file:

- **Browser Extension Export**: One-click export from the extension's developer mode panel
- **CLI Export**: Command-line rake task for terminal-based workflows
- **File Generation**: Creates timestamped JSON files in nested, human-readable format
- **Metadata Inclusion**: Exports include version, timestamp, and link count
- **Empty State Handling**: Creates valid export file even when no links exist
- **Storage Location**: Files saved to `data/exports/` directory with automatic directory creation

### 2.2. Import Capabilities

The system must provide the ability to import link data from files:

- **Browser Extension Import**: File upload in the extension's developer mode panel
- **CLI Import**: Command-line rake task accepting filename, importer name, and mode
- **Field Mapping**: Ruby DSL for mapping external data formats to LinkRadar structure
- **Flexible File Location**: CLI task checks `data/imports/` by default but accepts full path override
- **Mode Selection**: User chooses between skip (default) or update mode for duplicate handling
- **Extensible Importers**: Support for multiple importer definitions stored in `lib/importers/`

### 2.3. Data Management Interface

The system must provide a unified interface for data operations:

- **Developer Panel Integration**: Export and import functionality grouped in existing developer panel
- **Combined Section**: "Data Management" section containing both export and import controls
- **Simple Controls**: Export button and import file picker with mode selection dropdown
- **Mode Selection**: Dropdown for choosing import mode (skip duplicates as default)

## 3. Business Data Requirements

### 3.1. Export Data Structure

Export files must contain:

- **Format**: JSON with nested/denormalized structure
- **Metadata**: Version identifier, export timestamp, total link count
- **Link Records**: Each link includes URL, title, notes, tags array, and creation timestamp
- **Tag Representation**: Tags stored as simple string arrays within each link
- **Human Readability**: Structure optimized for manual review and editing
- **Self-Containment**: Each link record contains all its data including tag names

### 3.2. Import Field Mapping

Import mapping must support:

- **Field Name Translation**: Map source field names to LinkRadar field names
- **Required Mappings**: URL, title, notes, tags, timestamps
- **Importer Identity**: Each importer identifies its source format
- **Reusable Definitions**: Importers defined once and used repeatedly
- **Standard Location**: Importers stored in predictable location for discoverability

### 3.3. Tag Data

Tag handling must support:

- **Case-Insensitive Matching**: Find existing tags regardless of capitalization
- **Capitalization Preservation**: Existing tags keep their current capitalization
- **New Tag Creation**: Create new tags with exact capitalization from import
- **Name-Based Relationships**: Tags matched by name, not internal identifiers

## 4. Business Rules & Logic

### 4.1. Export Rules

- System must export all links for the current user
- System must generate timestamped filename in format `linkradar-export-YYYY-MM-DD-HHMMSS.json`
- System must include metadata showing version, export timestamp, and total link count
- System must create valid export file with empty links array when no links exist
- System must save files to `data/exports/` directory
- System must not show progress indicators or status updates during export

### 4.2. Import Rules

- System must wrap entire import operation in database transaction
- System must abort entire import if any error occurs (all-or-nothing)
- System must perform minimal validation (valid JSON structure only)
- System must rely on database constraints and ActiveRecord validations for data validation
- System must default to skip mode when mode not specified
- System must look for import files in `data/imports/` directory by default
- System must accept full path override for import file location
- System must find importer by name in standard location

### 4.3. Duplicate Detection

- System must detect duplicates by comparing URLs
- System must normalize URLs before comparison (strip trailing slashes, normalize case, remove fragments)
- System must treat normalized URLs as duplicates even if original formatting differs
- System must apply skip or update behavior based on selected mode

### 4.4. Tag Matching and Creation

- System must match tags case-insensitively by name
- System must use existing tag when case-insensitive match found
- System must preserve existing tag's capitalization when matched
- System must create new tag with exact capitalization from import when no match found
- System must maintain tag co-occurrence data (radar) through name-based relationships

### 4.5. Timestamp Preservation

- System must preserve `created_at` timestamp from import file when present
- System must use current import time for `created_at` when not present in import file
- System must keep original `created_at` unchanged when updating existing links in update mode

### 4.6. Import Modes

**Skip Mode (Default):**
- System must ignore links with duplicate URLs
- System must preserve all existing data for duplicates
- System must continue processing remaining links

**Update Mode:**
- System must overwrite all fields for links with duplicate URLs
- System must replace URL, title, notes, and tags completely
- System must keep original `created_at` timestamp
- System must treat update as complete replacement of link data

## 5. User Experience Requirements

### 5.1. Extension Interface

- Developer panel must contain dedicated "Data Management" section
- Export control must be simple button labeled "Export All Links"
- Import control must include file picker and mode selection dropdown
- Mode dropdown must show "Skip duplicates" as default option
- Mode dropdown must offer "Update existing" as alternative
- Interface must be accessible from existing developer panel toggle
- Controls must be visually grouped to show conceptual relationship

### 5.2. Feedback and Notifications

- System must show toast notification after export with "Exported X links" message
- System must show toast notification after successful import with "Imported X links, Y tags" message
- System must show toast notification after failed import with brief error message
- Toast messages must be non-intrusive and auto-dismiss
- Success messages must show actual counts of links and tags processed

### 5.3. Error Handling

- System must provide clear error messages when import fails
- System must include specific error information in toast notification
- System must roll back all changes when import fails
- System must leave system in clean state after import failure
- System must not require user to check console for basic error information

## 6. Quality Attributes & Constraints

### 6.1. Reliability

- Import transactions must be atomic (all-or-nothing)
- Export must not corrupt or lose data during file generation
- System must handle edge cases (empty data, malformed files) gracefully
- File operations must complete successfully or fail cleanly

### 6.2. Data Integrity

- Duplicate detection must be accurate and consistent
- Tag relationships must be preserved through import/export cycle
- Timestamps must be accurately preserved or generated
- Database constraints must be respected during import

### 6.3. Usability

- Export must require single click without additional configuration
- Import must require minimal steps (select file, choose mode, import)
- Error messages must be clear and actionable
- Interface must be discoverable within existing developer panel
- CLI tasks must follow Rails conventions

### 6.4. Performance

- No specific performance targets for v1
- System should handle typical solo developer dataset sizes
- Import/export operations expected to complete in reasonable time for personal use

### 6.5. Security

- No special security restrictions needed for developer-only functionality
- Standard application authentication and authorization apply
- File operations restricted to designated directories

## 7. Integration Touchpoints

### 7.1. Browser Extension Integration

- Export/import functionality integrated into existing developer panel in options page
- Developer panel accessed via toggle switch in top-right corner
- File downloads triggered through browser extension API
- File uploads handled through extension file picker

### 7.2. Backend API Integration

- Extension communicates with backend API for export/import operations
- API endpoints handle data serialization and deserialization
- Backend manages file generation and processing
- Transaction management handled at backend layer

### 7.3. File System Integration

- Export files written to `data/exports/` directory
- Import files read from `data/imports/` directory (with full path override)
- Directory structure compatible with Docker volume mapping
- Automatic directory creation when needed

### 7.4. External System Compatibility

- Export format compatible with re-import (round-trip support)
- Import system supports external formats through custom importers
- Initial importers provided for LinkRadar native format and Notion
- Importer DSL enables future integration with additional external systems

## 8. Development & Testing Approach

### 8.1. Development Strategy

- Build export functionality first (foundation for testing import)
- Implement import with skip mode before update mode
- Create base importer class and DSL structure
- Implement LinkRadar native format importer for testing
- Add Notion importer as example external integration
- Extension UI integration after backend API complete

### 8.2. Testing Strategy

- Test export with various dataset sizes (empty, small, typical)
- Test import with skip and update modes
- Verify duplicate detection with normalized URLs
- Test tag matching case-insensitivity
- Test timestamp preservation logic
- Test transaction rollback on error
- Test field mapping DSL with multiple importer definitions
- Verify round-trip integrity (export then import)
- Test Docker volume mapping for `data/` directories

## 9. Success Criteria

### 9.1. Acceptance Criteria

**Export:**
- ✓ User can click export button in extension and receive timestamped JSON file
- ✓ User can run rake task and find export in `data/exports/` directory
- ✓ Export file contains all links with complete data
- ✓ Export includes metadata with version, timestamp, and count
- ✓ Export succeeds even with zero links

**Import:**
- ✓ User can upload file in extension and see success message with counts
- ✓ User can run rake task with filename only (checks `data/imports/`)
- ✓ User can specify full path to import file
- ✓ Skip mode preserves existing links with duplicate URLs
- ✓ Update mode overwrites existing links completely
- ✓ Tags matched case-insensitively and existing capitalization preserved
- ✓ New tags created with exact capitalization from import
- ✓ Import fails cleanly with no partial data on error

**Developer Experience:**
- ✓ Export/import accessible from developer panel in extension
- ✓ Interface grouped in "Data Management" section
- ✓ Success shows toast with meaningful counts
- ✓ Errors show toast with actionable message
- ✓ No context-switch required for basic export/import workflows

### 9.2. Definition of Success

The feature succeeds when a developer can:

1. Export their LinkRadar data before a schema change
2. Perform database migration/rearchitecture
3. Import data back successfully with all links and tags preserved
4. Start actively dogfooding LinkRadar with confidence

Secondary success: Can write simple importer for external system (Notion) and migrate bookmarks with minimal friction.

## 10. Constraints & Assumptions

### 10.1. Scope Boundaries

**In Scope for v1:**
- Basic export and import functionality
- Two import modes (skip, update)
- Simple field mapping DSL
- Tag name-based matching
- Transaction-based safety
- CLI and extension interfaces

**Out of Scope for v1:**
- Snapshot management UI (list, delete snapshots)
- Validation/preview before import
- Rollback mechanism
- Compression or zip files
- Multiple export formats
- Scheduled/automatic exports
- Incremental exports
- Export filtering
- Advanced merge strategies
- Content archival (feature doesn't exist yet)
- Cloud backup integration

See [future.md](./future.md) for deferred features in Phase 2+.

### 10.2. Assumptions

- **Solo Developer Use**: Feature designed for single developer actively dogfooding system
- **Not Disaster Recovery**: PostgreSQL pg_dump handles disaster recovery; this feature is for development velocity
- **Trusted Data**: Import files from LinkRadar exports or known external sources
- **Docker Deployment**: `data/` directory structure maps to Docker volumes
- **Known External Formats**: Initial external importers for systems developer actively uses
- **Manual Operations**: Export/import are deliberate manual actions, not automated processes
- **Reasonable Dataset Sizes**: Solo developer bookmark collection (hundreds to low thousands)
- **No Multi-User**: Single user per instance, no workspace/team considerations

---

**Cross-References:**
- Strategic context and business case: [vision.md](./vision.md)
- Future enhancements and phases: [future.md](./future.md)

