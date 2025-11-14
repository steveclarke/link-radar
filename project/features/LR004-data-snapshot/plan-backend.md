# LR004 - Data Snapshot & Import System: Backend Plan

## Overview

This plan implements the backend foundation for frictionless data export and flexible import capabilities. The implementation provides both CLI (Rake tasks) and API endpoints for exporting LinkRadar data to timestamped JSON files and importing data back.

**What we're building:**
- Schema simplification (remove unused `submitted_url` and `metadata` fields)
- Export service with reserved tag filtering and UUID-based filename security
- Import service with transaction safety and dual-mode duplicate handling
- API endpoints for extension integration
- Rake tasks for CLI workflows

**Key components:**
- `Link` model - URL normalization via `before_validation` callback (Addressable gem, defaults to HTTPS)
- `LinkRadar::DataExport::Exporter` - Export service with `~temp~` tag filtering
- `LinkRadar::DataImport::Importer` - Import service with skip/update modes (delegates to Link model for normalization)
- `Api::V1::SnapshotController` - Export/import/download endpoints
- Rake tasks: `snapshot:export` and `snapshot:import`
- Snapshot directories: `snapshots/exports/` and `snapshots/imports/`

**Sequencing logic:**
1. Schema simplification first (foundation for cleaner export/import)
2. Export before import (export generates test data for import validation)
3. Each phase includes smoke tests appropriate to the component
4. Documentation last to capture complete feature

**Cross-references:**
- Technical spec: [spec.md](./spec.md)
- Requirements: [requirements.md](./requirements.md)
- Vision: [vision.md](./vision.md)

---

## Table of Contents

1. [Phase 1: Schema Simplification](#1-phase-1-schema-simplification)
2. [Phase 2: Export System](#2-phase-2-export-system)
3. [Phase 3: Import System](#3-phase-3-import-system)
4. [Phase 4: Testing & Validation](#4-phase-4-testing--validation)
5. [Phase 5: Documentation](#5-phase-5-documentation)

---

## 1. Phase 1: Schema Simplification

**Implements:** [spec.md#3](./spec.md#3-url-field-simplification)

**Justification:** Remove unused fields (`submitted_url`, `metadata`) to simplify the mental model and reduce export/import complexity. The system never needs the original user input - only the normalized URL matters for a bookmark manager.

### 1.1. Database Migration - Remove Unused Fields

- [x] Create migration file

```ruby
# frozen_string_literal: true

# Remove unused submitted_url and metadata fields from links table
#
# submitted_url was used to store original user input, but we only need
# the normalized url field. Original input adds unnecessary complexity.
#
# metadata was a jsonb field that was never populated or used anywhere.
class RemoveUnusedFieldsFromLinks < ActiveRecord::Migration[7.2]
  def change
    # Remove submitted_url column (original user input, no longer needed)
    remove_column :links, :submitted_url, :string, limit: 2048, null: false

    # Remove metadata column and its GIN index
    remove_index :links, name: "index_links_on_metadata", if_exists: true
    remove_column :links, :metadata, :jsonb
  end
end
```

- [x] Run migration: `bin/rails db:migrate`
- [x] Verify schema: `bin/rails db:schema:dump` and check `db/schema.rb`

### 1.2. Update Link Model

- [x] Remove `submitted_url` validation from `app/models/link.rb`

Remove this line:

```ruby
validates :submitted_url, presence: true, length: {maximum: 2048}
```

- [x] Verify Link model only validates `url` field

### 1.3. Update LinksController - Accept `url` Parameter

- [x] Update `app/controllers/api/v1/links_controller.rb`

**IMPLEMENTATION NOTE:** URL normalization was refactored to live in the Link model (proper MVC separation) rather than the controller. The controller was simplified significantly:

**Final `create` action:**

```ruby
# POST /api/v1/links
def create
  @link = Link.new(link_params)

  if @link.save
    render :show, status: :created
  else
    render json: {errors: @link.errors.full_messages}, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordNotUnique
  render json: {error: "A link with this URL already exists"}, status: :unprocessable_entity
end
```

**Final `update` action:**

```ruby
# PATCH/PUT /api/v1/links/:id
def update
  if @link.update(link_params)
    render :show
  else
    render json: {errors: @link.errors.full_messages}, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordNotUnique
  render json: {error: "A link with this URL already exists"}, status: :unprocessable_entity
end
```

**Parameter methods (Rails 8 syntax):**

```ruby
def link_params
  params.expect(link: [:url, :note, {tag_names: []}])
end
```

- [x] URL normalization moved to Link model as `before_validation` callback
- [x] Link model handles all URL validation and normalization logic
- [x] Controller simplified - no URL business logic

### 1.4. Smoke Test - Verify Schema Changes

- [x] Start Rails console: `bin/rails console`
- [x] Create test link: `Link.create!(url: "https://example.com", note: "Test")`
- [x] Verify link saved successfully
- [x] Verify no `submitted_url` or `metadata` columns exist
- [x] Clean up: `Link.destroy_all`

### 1.5. URL Normalization Refactor (Additional Work)

**Completed additional improvements beyond original plan:**

- [x] Moved URL normalization from controller to Link model
  - Added `before_validation :normalize_url` callback
  - Added `validate :url_must_be_valid` custom validation
  - Uses Addressable gem for robust URL parsing
  - Defaults to HTTPS (industry standard in 2025, not HTTP)
  
- [x] Created shared normalization logic (DRY principle)
  - `Link.normalize_url_string(url)` - class method for normalization algorithm
  - `Link.find_by_url(url)` - class method for URL-based queries with normalization
  - Instance `normalize_url` callback reuses class method
  
- [x] Simplified LinksController completely
  - Removed all URL normalization logic
  - Removed all URL validation logic  
  - Updated to Rails 8 `params.expect` syntax
  - Consolidated duplicate `link_params`/`link_update_params` methods
  
- [x] Updated factories and sample data loaders
  - Removed `submitted_url` references
  - Updated tests to reflect model-based normalization
  
- [x] All 182 specs passing

**Result:** Proper MVC separation - Link model owns all URL behavior, controller handles only HTTP concerns.

---

## 2. Phase 2: Export System

**Implements:** [spec.md#5](./spec.md#5-export-system-architecture), [requirements.md#2.1](./requirements.md#21-export-capabilities)

**Justification:** Export functionality is the foundation - it generates test data for import validation and provides the safety net for schema iteration.

### 2.1. Create Export Service

- [x] Create directory: `mkdir -p lib/link_radar/data_export`
- [x] Create service file: `lib/link_radar/data_export/exporter.rb`

```ruby
# frozen_string_literal: true

module LinkRadar
  module DataExport
    # Exports all links to JSON file with reserved tag filtering
    #
    # This service handles the complete export workflow:
    # 1. Query all links with eager-loaded tags
    # 2. Filter out links tagged with ~temp~ (test/temporary data)
    # 3. Serialize to nested JSON format (human-readable, denormalized)
    # 4. Generate timestamped filename with UUID (unguessable for security)
    # 5. Write to snapshots/exports/ directory
    # 6. Return file path and statistics
    #
    # The export format is nested/denormalized - each link contains embedded
    # tag data (names + descriptions). Tags are matched by name on import,
    # not by ID, which allows IDs to change across database migrations.
    #
    # Reserved Tags:
    # - Links tagged with ~temp~ are excluded from all exports
    # - Use ~temp~ for testing in production without polluting backups
    #
    # @example Export all links
    #   exporter = Exporter.new
    #   result = exporter.call
    #   if result.success?
    #     puts result.data[:file_path]  # => "snapshots/exports/linkradar-export-2025-11-12-143022-uuid.json"
    #     puts result.data[:link_count] # => 42
    #   end
    #
    class Exporter
      include LinkRadar::Resultable

      # Export directory path (Docker volume compatible)
      EXPORT_DIR = Rails.root.join("snapshots", "exports")

      # Reserved tag name for excluding links from exports
      TEMP_TAG = "~temp~"

      # Export format version for future compatibility
      FORMAT_VERSION = "1.0"

      # Export all links to timestamped JSON file
      #
      # @return [LinkRadar::Result] Success with file path and counts, or failure with errors
      def call
        links = fetch_links
        json_data = build_json(links)
        file_path = write_file(json_data)

        success({
          file_path: file_path.to_s,
          link_count: links.size,
          tag_count: count_unique_tags(links)
        })
      rescue => e
        failure("Export failed: #{e.message}")
      end

      private

      # Fetch all links with tags, excluding ~temp~ tagged links
      #
      # Uses eager loading to prevent N+1 queries when accessing tags.
      # Filters out any link that has the ~temp~ tag.
      #
      # @return [Array<Link>] links to export
      def fetch_links
        Link.includes(:tags)
          .where.not(id: Link.joins(:tags).where(tags: {name: TEMP_TAG}))
          .order(created_at: :asc)
      end

      # Build JSON structure with metadata and links
      #
      # Creates nested/denormalized format where each link contains embedded
      # tag data. This format is human-readable and preserves relationships
      # by tag name (not ID).
      #
      # @param links [Array<Link>] links to serialize
      # @return [Hash] JSON-serializable hash
      def build_json(links)
        {
          version: FORMAT_VERSION,
          exported_at: Time.current.utc.iso8601,
          metadata: {
            link_count: links.size,
            tag_count: count_unique_tags(links)
          },
          links: links.map { |link| serialize_link(link) }
        }
      end

      # Serialize a single link with embedded tags
      #
      # @param link [Link] link to serialize
      # @return [Hash] serialized link data
      def serialize_link(link)
        {
          url: link.url,
          note: link.note,
          created_at: link.created_at.utc.iso8601,
          tags: link.tags.map { |tag| serialize_tag(tag) }
        }
      end

      # Serialize a single tag
      #
      # @param tag [Tag] tag to serialize
      # @return [Hash] serialized tag data
      def serialize_tag(tag)
        {
          name: tag.name,
          description: tag.description
        }
      end

      # Count unique tags across all links
      #
      # @param links [Array<Link>] links to count tags from
      # @return [Integer] count of unique tags
      def count_unique_tags(links)
        links.flat_map(&:tags).map(&:id).uniq.size
      end

      # Write JSON to file with timestamped filename and UUID
      #
      # Filename format: linkradar-export-YYYY-MM-DD-HHMMSS-<uuid>.json
      # UUID makes filename unguessable for download security.
      #
      # @param json_data [Hash] data to write
      # @return [Pathname] full path to created file
      def write_file(json_data)
        FileUtils.mkdir_p(EXPORT_DIR)

        timestamp = Time.current.utc.strftime("%Y-%m-%d-%H%M%S")
        uuid = SecureRandom.uuid
        filename = "linkradar-export-#{timestamp}-#{uuid}.json"
        file_path = EXPORT_DIR.join(filename)

        File.write(file_path, JSON.pretty_generate(json_data))
        file_path
      end
    end
  end
end
```

- [x] Verify file created and documented

### 2.2. Create Export Rake Task

- [x] Create file: `lib/tasks/snapshot.rake`

```ruby
# frozen_string_literal: true

namespace :snapshot do
  desc "Export all links to JSON file (excludes ~temp~ tagged links)"
  task export: :environment do
    puts "Exporting links..."

    exporter = LinkRadar::DataExport::Exporter.new
    result = exporter.call

    if result.success?
      puts "✓ Export successful!"
      puts "  File: #{result.data[:file_path]}"
      puts "  Links: #{result.data[:link_count]}"
      puts "  Tags: #{result.data[:tag_count]}"
    else
      puts "✗ Export failed:"
      result.errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end

  desc "Import links from JSON file"
  task :import, [:file, :mode] => :environment do |_t, args|
    # Implementation in Phase 3
    puts "Import task not yet implemented"
  end
end
```

- [x] Verify task appears in `bin/rake -T snapshot`

### 2.3. Create Snapshot Controller - Export Endpoint

- [x] Create file: `app/controllers/api/v1/snapshot_controller.rb`

Follow standard Rails controller pattern from existing controllers (e.g., `links_controller.rb`):

```ruby
module Api
  module V1
    class SnapshotController < ApplicationController
      # POST /api/v1/snapshot/export
      # Export all links to JSON file and return download URL
      def export
        exporter = LinkRadar::DataExport::Exporter.new
        result = exporter.call

        if result.success?
          # Extract filename from full path for download URL
          filename = File.basename(result.data[:file_path])

          render json: {
            data: {
              file_path: filename,
              link_count: result.data[:link_count],
              tag_count: result.data[:tag_count],
              download_url: "/api/v1/snapshot/exports/#{filename}"
            }
          }
        else
          render json: {error: result.errors.join(", ")}, status: :internal_server_error
        end
      end

      # GET /api/v1/snapshot/exports/:filename
      # Download export file (requires authentication)
      def download
        filename = params[:filename]
        file_path = Rails.root.join("snapshots", "exports", filename)

        # Security: Only allow downloads from exports directory
        # Prevent directory traversal attacks
        unless file_path.to_s.start_with?(Rails.root.join("snapshots", "exports").to_s)
          render json: {error: "Invalid file path"}, status: :forbidden
          return
        end

        unless File.exist?(file_path)
          render json: {error: "File not found"}, status: :not_found
          return
        end

        send_file file_path,
          type: "application/json",
          disposition: "attachment",
          filename: filename
      end

      # POST /api/v1/snapshot/import
      # Import links from uploaded JSON file
      def import
        # Implementation in Phase 3
        render json: {error: "Import not yet implemented"}, status: :not_implemented
      end
    end
  end
end
```

- [x] Add routes to `config/routes.rb`

```ruby
namespace :api do
  namespace :v1 do
    # ... existing routes ...
    
    # Snapshot export/import
    post "snapshot/export", to: "snapshot#export"
    post "snapshot/import", to: "snapshot#import"
    get "snapshot/exports/:filename", to: "snapshot#download", constraints: {filename: /[^\\/]+/}, defaults: {format: false}
  end
end
```

- [x] Verify routes: `bin/rails routes | grep snapshot`

### 2.4. Smoke Test - Export Flow

- [x] Create sample data in Rails console:

```ruby
# Create a few test links with tags
link1 = Link.create!(url: "https://example.com", note: "Example site")
link1.tag_names = ["test", "example"]
link1.save!

link2 = Link.create!(url: "https://ruby-lang.org", note: "Ruby programming")
link2.tag_names = ["ruby", "programming"]
link2.save!

# Create a temp link (should be excluded from export)
temp_link = Link.create!(url: "https://temp.com", note: "Temporary")
temp_link.tag_names = ["~temp~"]
temp_link.save!
```

- [x] Test rake task: `bin/rake snapshot:export`
- [x] Verify file created in `snapshots/exports/` directory
- [x] Open file and verify:
  - Contains links (temp links excluded)
  - Each link has embedded tags array
  - Metadata shows correct counts
  - JSON is pretty-printed and readable
- [x] Test API endpoint via curl or Bruno:

```bash
# Export
curl -X POST http://localhost:3000/api/v1/snapshot/export \
  -H "Authorization: Bearer YOUR_API_KEY"

# Download (use filename from export response)
curl http://localhost:3000/api/v1/snapshot/exports/linkradar-export-YYYY-MM-DD-HHMMSS-uuid.json \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -o downloaded-export.json
```

- [x] Verify ~temp~ tag filtering works correctly
- [x] Verify path traversal security protection

---

## 3. Phase 3: Import System

**Implements:** [spec.md#6](./spec.md#6-import-system-architecture), [requirements.md#2.2](./requirements.md#22-import-capabilities), [requirements.md#4.2-4.6](./requirements.md#42-import-modes)

**Justification:** Import system provides the safety net for schema changes and enables data migration. Transaction safety ensures all-or-nothing imports. Dual-mode handling (skip/update) gives flexibility for different use cases.

### 3.1. Create Import Service

- [x] Create directory: `mkdir -p lib/link_radar/data_import`
- [x] Create service file: `lib/link_radar/data_import/importer.rb`

```ruby
# frozen_string_literal: true

module LinkRadar
  module DataImport
    # Imports links from JSON file with transaction safety and duplicate handling
    #
    # This service handles the complete import workflow:
    # 1. Parse JSON file (LinkRadar native format only)
    # 2. Validate basic structure (version, required fields)
    # 3. Wrap entire import in database transaction (all-or-nothing)
    # 4. Process each link with URL normalization
    # 5. Handle duplicates based on selected mode (skip or update)
    # 6. Match tags case-insensitively by name
    # 7. Return statistics on import results
    #
    # Import Modes:
    # - :skip (default) - Skip existing links, keep all existing data unchanged
    # - :update - Replace existing links completely (except created_at timestamp)
    #
    # Tag Matching:
    # - Tags matched case-insensitively by name
    # - Existing tags preserve their capitalization, slug, usage_count
    # - New tags created with exact capitalization from import
    #
    # @example Import with skip mode (default)
    #   importer = Importer.new(file_path: "snapshots/imports/export.json")
    #   result = importer.call
    #   result.data[:links_imported] # => 38
    #   result.data[:links_skipped]  # => 4
    #
    # @example Import with update mode
    #   importer = Importer.new(file_path: "snapshots/imports/export.json", mode: :update)
    #   result = importer.call
    #
    class Importer
      include LinkRadar::Resultable

      # Supported import modes
      MODES = [:skip, :update].freeze

      # @param file_path [String] Full path to import file
      # @param mode [Symbol] Import mode - :skip (default) or :update
      def initialize(file_path:, mode: :skip)
        @file_path = file_path
        @mode = mode.to_sym

        unless MODES.include?(@mode)
          raise ArgumentError, "Invalid mode: #{mode}. Must be one of: #{MODES.join(", ")}"
        end
      end

      # Import links from file
      #
      # @return [LinkRadar::Result] Success with import statistics or failure with errors
      def call
        data = parse_file
        validate_structure(data)

        stats = {
          links_imported: 0,
          links_skipped: 0,
          tags_created: 0,
          tags_reused: 0
        }

        # Wrap entire import in transaction for all-or-nothing safety
        Link.transaction do
          data["links"].each do |link_data|
            process_link(link_data, stats)
          end
        end

        success(stats)
      rescue JSON::ParserError => e
        failure("Invalid JSON format: #{e.message}")
      rescue => e
        failure("Import failed: #{e.message}")
      end

      private

      # Parse JSON file
      #
      # @return [Hash] parsed JSON data
      # @raise [Errno::ENOENT] if file not found
      # @raise [JSON::ParserError] if invalid JSON
      def parse_file
        JSON.parse(File.read(@file_path))
      end

      # Validate JSON structure
      #
      # Performs minimal validation - just checks required fields exist.
      # Database constraints and ActiveRecord validations handle data validation.
      #
      # @param data [Hash] parsed JSON data
      # @raise [StandardError] if structure invalid
      def validate_structure(data)
        unless data["version"] == "1.0"
          raise "Unsupported version: #{data["version"]}"
        end

        unless data["links"].is_a?(Array)
          raise "Invalid structure: 'links' must be an array"
        end
      end

      # Process a single link from import data
      #
      # Handles URL normalization, duplicate detection, mode logic,
      # and tag assignment. Updates statistics hash in-place.
      #
      # @param link_data [Hash] link data from import
      # @param stats [Hash] statistics hash (mutated in-place)
      # @return [void]
      def process_link(link_data, stats)
        normalized_url = normalize_url(link_data["url"])

        case @mode
        when :skip
          process_skip_mode(normalized_url, link_data, stats)
        when :update
          process_update_mode(normalized_url, link_data, stats)
        end
      end

      # Process link in skip mode (default)
      #
      # Skip mode behavior:
      # - If URL exists: skip entirely, no changes to link or tags
      # - If URL is new: create with imported data
      #
      # @param normalized_url [String] normalized URL
      # @param link_data [Hash] link data from import
      # @param stats [Hash] statistics hash (mutated in-place)
      # @return [void]
      def process_skip_mode(normalized_url, link_data, stats)
        if Link.exists?(url: normalized_url)
          stats[:links_skipped] += 1
          return
        end

        # Create new link
        link = Link.new(
          url: normalized_url,
          note: link_data["note"],
          created_at: parse_timestamp(link_data["created_at"])
        )

        # Assign tags (creates or finds by name)
        assign_tags_to_link(link, link_data["tags"], stats)

        link.save!
        stats[:links_imported] += 1
      end

      # Process link in update mode
      #
      # Update mode behavior:
      # - If URL exists: replace all fields except created_at
      # - If URL is new: create with imported data (including created_at)
      #
      # @param normalized_url [String] normalized URL
      # @param link_data [Hash] link data from import
      # @param stats [Hash] statistics hash (mutated in-place)
      # @return [void]
      def process_update_mode(normalized_url, link_data, stats)
        link = Link.find_or_initialize_by(url: normalized_url)

        if link.persisted?
          # Existing link: update fields but preserve original created_at
          link.assign_attributes(
            note: link_data["note"]
            # created_at intentionally not updated - preserve original
          )
        else
          # New link: use imported created_at
          link.assign_attributes(
            note: link_data["note"],
            created_at: parse_timestamp(link_data["created_at"])
          )
        end

        # Assign tags (replaces existing tags completely)
        assign_tags_to_link(link, link_data["tags"], stats)

        link.save!
        stats[:links_imported] += 1
      end

      # Assign tags to link with case-insensitive matching
      #
      # Tag matching logic:
      # - Find existing tag by case-insensitive name match
      # - Use existing tag if found (preserves slug, usage_count)
      # - Create new tag if not found (exact capitalization from import)
      #
      # Tag association uses replacement strategy (not merge):
      # - Replaces link's entire tag collection
      # - Follows existing Link model assign_tags pattern
      # - Tag usage_count recalculated via callbacks
      #
      # @param link [Link] link to assign tags to
      # @param tag_data [Array<Hash>] tag data from import
      # @param stats [Hash] statistics hash (mutated in-place)
      # @return [void]
      def assign_tags_to_link(link, tag_data, stats)
        return if tag_data.blank?

        tags = tag_data.map do |tag_hash|
          find_or_create_tag(tag_hash, stats)
        end

        # Replace all tags (follows Link model pattern)
        link.tags = tags
      end

      # Find or create tag with case-insensitive name matching
      #
      # @param tag_data [Hash] tag data from import
      # @param stats [Hash] statistics hash (mutated in-place)
      # @return [Tag] existing or new tag
      def find_or_create_tag(tag_data, stats)
        tag_name = tag_data["name"]
        tag_description = tag_data["description"]

        # Find existing tag by case-insensitive name match
        existing_tag = Tag.where("LOWER(name) = ?", tag_name.downcase).first

        if existing_tag
          stats[:tags_reused] += 1
          # Update description if provided in import and currently blank
          if tag_description.present? && existing_tag.description.blank?
            existing_tag.update!(description: tag_description)
          end
          existing_tag
        else
          # Create new tag with exact capitalization from import
          stats[:tags_created] += 1
          Tag.create!(name: tag_name, description: tag_description)
        end
      end

      # Normalize URL for comparison
      #
      # Delegates to Link model's normalization logic for consistency.
      # Link model automatically normalizes URLs on save, so import service
      # uses the same algorithm for duplicate detection.
      #
      # @param url [String] URL to normalize
      # @return [String] normalized URL
      # @raise [Addressable::URI::InvalidURIError] if URL invalid
      def normalize_url(url)
        Link.normalize_url_string(url)
      end

      # Parse timestamp from ISO8601 string
      #
      # @param timestamp_str [String, nil] ISO8601 timestamp string
      # @return [Time] parsed timestamp or current time if nil
      def parse_timestamp(timestamp_str)
        return Time.current if timestamp_str.blank?
        Time.zone.parse(timestamp_str)
      end
    end
  end
end
```

- [x] Verify file created and documented

### 3.2. Update Rake Task - Add Import

- [x] Update `lib/tasks/snapshot.rake` to add import task implementation:

```ruby
desc "Import links from JSON file"
task :import, [:file, :mode] => :environment do |_t, args|
  unless args[:file]
    puts "Usage: rake snapshot:import[filename.json] or rake snapshot:import[filename.json,update]"
    puts "  Mode: skip (default) or update"
    exit 1
  end

  # Determine file path (check snapshots/imports/ directory first, then treat as full path)
  file_path = if File.exist?(args[:file])
    args[:file]
  else
    Rails.root.join("snapshots", "imports", args[:file])
  end

  unless File.exist?(file_path)
    puts "✗ File not found: #{file_path}"
    exit 1
  end

  mode = args[:mode].presence&.to_sym || :skip

  puts "Importing links from #{file_path}..."
  puts "Mode: #{mode}"

  importer = LinkRadar::DataImport::Importer.new(file_path: file_path, mode: mode)
  result = importer.call

  if result.success?
    puts "✓ Import successful!"
    puts "  Links imported: #{result.data[:links_imported]}"
    puts "  Links skipped: #{result.data[:links_skipped]}"
    puts "  Tags created: #{result.data[:tags_created]}"
    puts "  Tags reused: #{result.data[:tags_reused]}"
  else
    puts "✗ Import failed:"
    result.errors.each { |error| puts "  - #{error}" }
    exit 1
  end
end
```

- [x] Verify task shows usage: `bin/rake snapshot:import`

### 3.3. Update Snapshot Controller - Add Import Endpoint

- [x] Update `app/controllers/api/v1/snapshot_controller.rb` to implement import action:

```ruby
# POST /api/v1/snapshot/import
# Import links from uploaded JSON file
def import
  unless params[:file].present?
    render json: {error: "No file provided"}, status: :bad_request
    return
  end

  # Get uploaded file
  uploaded_file = params[:file]
  mode = params[:mode].presence&.to_sym || :skip

  # Save to temporary location for processing
  temp_path = Rails.root.join("tmp", "import-#{SecureRandom.uuid}.json")
  File.write(temp_path, uploaded_file.read)

  importer = LinkRadar::DataImport::Importer.new(file_path: temp_path.to_s, mode: mode)
  result = importer.call

  # Clean up temp file
  File.delete(temp_path) if File.exist?(temp_path)

  if result.success?
    render json: {data: result.data}
  else
    render json: {error: result.errors.join(", ")}, status: :unprocessable_entity
  end
rescue => e
  # Clean up temp file on error
  File.delete(temp_path) if temp_path && File.exist?(temp_path)
  render json: {error: "Import failed: #{e.message}"}, status: :internal_server_error
end
```

- [x] Update `import_params` if needed (multipart form data handling is automatic)

### 3.4. Smoke Test - Import Flow

- [x] Create `snapshots/imports/` directory: `mkdir -p snapshots/imports`
- [x] Copy an export file to imports directory
- [x] Clear database: `Link.destroy_all; Tag.destroy_all` in Rails console
- [x] Test import with skip mode: `bin/rake snapshot:import[linkradar-export-*.json]`
- [x] Verify links and tags imported correctly in Rails console
- [x] Test duplicate handling:
  - Run same import again: `bin/rake snapshot:import[linkradar-export-*.json]`
  - Verify `links_skipped` count equals total (all duplicates)
- [x] Test update mode:
  - Manually edit a note in database
  - Run import with update mode: `bin/rake snapshot:import[linkradar-export-*.json,update]`
  - Verify note was overwritten with imported value
  - Verify `created_at` was NOT changed
- [x] Test API endpoint via curl or Bruno:

```bash
curl -X POST http://localhost:3000/api/v1/snapshot/import \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -F "file=@snapshots/exports/linkradar-export-*.json" \
  -F "mode=skip"
```

- [x] Test error handling:
  - Invalid JSON file
  - Missing required fields
  - Invalid URL format
  - Verify transaction rollback (no partial imports)

---

## 4. Phase 4: Testing & Validation

**Implements:** [requirements.md#8.2](./requirements.md#82-testing-strategy)

**Justification:** Smoke tests validate core functionality and edge cases. Focus on happy path and critical error scenarios.

### 4.1. Export Service Smoke Tests

- [x] Create file: `spec/lib/link_radar/data_export/exporter_spec.rb`

Follow standard RSpec pattern from existing service specs. Test outline:

**Test scenarios:**
- With links and tags:
  - Returns success with file path and counts
  - Creates valid JSON file with correct structure
  - Generates filename with timestamp and UUID
  - Creates pretty-printed JSON (human-readable)
- With ~temp~ tagged links:
  - Excludes ~temp~ tagged links from export
  - Excludes ~temp~ tag from tag count
- With empty database:
  - Creates valid empty export
- Error handling:
  - Creates directory if it doesn't exist
  - Returns failure when file write fails

**Temp directory handling:**
- Uses `stub_const` to redirect EXPORT_DIR to `tmp/test_exports`
- Cleans up temp directory after each test
- Prevents cluttering `snapshots/exports/` with test files

- [x] Run specs: `bin/rspec spec/lib/link_radar/data_export/`
- [x] Verify all tests pass (9 examples, 0 failures)

### 4.2. Import Service Smoke Tests

- [ ] Create file: `spec/lib/link_radar/data_import/importer_spec.rb`

Follow standard RSpec pattern from existing service specs. Test outline:

**Test scenarios:**
- With valid data in skip mode:
  - Imports all links and tags with correct statistics
  - Preserves imported created_at timestamps
- With duplicate URLs in skip mode:
  - Skips duplicates and preserves existing data
- With duplicate URLs in update mode:
  - Updates link data but preserves original created_at
- With case-insensitive tag matching:
  - Reuses existing tag regardless of case
  - Preserves original tag capitalization
- With invalid data:
  - Returns failure for invalid JSON
  - Returns failure for unsupported version
- With transaction rollback:
  - Rolls back all changes on error (no partial imports)

- [ ] Run specs: `bin/rspec spec/lib/link_radar/data_import/`
- [ ] Verify all tests pass

### 4.3. Round-Trip Integration Test

- [ ] Test complete export/import cycle:

```ruby
# In Rails console
# 1. Create sample data
link = Link.create!(url: "https://example.com", note: "Test link")
link.tag_names = ["ruby", "rails"]
link.save!

original_created_at = link.created_at

# 2. Export
exporter = LinkRadar::DataExport::Exporter.new
export_result = exporter.call
export_file = export_result.data[:file_path]

# 3. Clear database
Link.destroy_all
Tag.destroy_all

# 4. Import
importer = LinkRadar::DataImport::Importer.new(file_path: export_file, mode: :skip)
import_result = importer.call

# 5. Verify data restored
link = Link.first
puts "URL: #{link.url}"
puts "Note: #{link.note}"
puts "Tags: #{link.tags.map(&:name).join(", ")}"
puts "Created at preserved: #{link.created_at.to_i == original_created_at.to_i}"
```

- [ ] Verify all data matches original (including timestamps)

---

## 5. Phase 5: Documentation

**Implements:** [requirements.md#9](./requirements.md#9-success-criteria)

**Justification:** Documentation enables developers to use the feature effectively and serves as reference for future maintenance.

### 5.1. Update Backend README

- [ ] Add section to `backend/README.md`:

```markdown
## Data Export & Import

LinkRadar provides export and import capabilities for backing up data during development and migrating bookmarks from external systems.

### CLI Usage

**Export all links:**

```bash
bin/rake snapshot:export
```

Creates timestamped JSON file in `snapshots/exports/` directory. Links tagged with `~temp~` are excluded.

**Import from file:**

```bash
# Import with skip mode (default - skip duplicates)
bin/rake snapshot:import[filename.json]

# Import with update mode (overwrite existing links)
bin/rake snapshot:import[filename.json,update]
```

Files in `snapshots/imports/` can be referenced by filename only. Full paths also supported.

### Import Modes

- **Skip mode (default)**: Ignore duplicate URLs, preserve existing data
- **Update mode**: Overwrite existing links completely (except `created_at` timestamp)

Duplicates detected by normalized URL comparison.

### Reserved Tags

Links tagged with `~temp~` are excluded from all exports. Use this for testing in production without polluting backups.

### API Endpoints

**Export:**
```
POST /api/v1/snapshot/export
Authorization: Bearer <token>

Response:
{
  "data": {
    "file_path": "linkradar-export-2025-11-12-143022-uuid.json",
    "link_count": 42,
    "tag_count": 15,
    "download_url": "/api/v1/snapshot/exports/linkradar-export-2025-11-12-143022-uuid.json"
  }
}
```

**Download:**
```
GET /api/v1/snapshot/exports/:filename
Authorization: Bearer <token>
```

**Import:**
```
POST /api/v1/snapshot/import
Authorization: Bearer <token>
Content-Type: multipart/form-data

Parameters:
- file: JSON file (LinkRadar format)
- mode: "skip" or "update" (optional, defaults to "skip")

Response:
{
  "data": {
    "links_imported": 38,
    "links_skipped": 4,
    "tags_created": 12,
    "tags_reused": 8
  }
}
```

### Data Format

Export files use nested/denormalized JSON format:

```json
{
  "version": "1.0",
  "exported_at": "2025-11-12T14:30:22Z",
  "metadata": {
    "link_count": 2,
    "tag_count": 2
  },
  "links": [
    {
      "url": "https://example.com",
      "note": "Example site",
      "created_at": "2025-11-01T10:00:00Z",
      "tags": [
        {"name": "ruby", "description": "Ruby programming language"},
        {"name": "rails", "description": null}
      ]
    }
  ]
}
```

Tags matched by name (case-insensitive) on import. IDs regenerated.

### Docker Volume Mapping

`snapshots/` directory is mapped as Docker volume for persistence. Export/import files accessible from both container and host system.
```

- [ ] Verify documentation is accurate and complete

---

## Implementation Status

**Completed phases:**
- ✅ **Phase 1: Schema Simplification** - COMPLETE
  - Removed `submitted_url` and `metadata` columns
  - Refactored URL normalization to Link model (proper MVC)
  - Uses Addressable gem, defaults to HTTPS
  - Updated to Rails 8 `params.expect` syntax
  - All 182 specs passing

**Completed phases:**
- ✅ **Phase 2: Export System** - COMPLETE
  - Export service with ~temp~ tag filtering
  - Rake task: `snapshot:export`
  - API endpoints: `POST /api/v1/snapshot/export`, `GET /api/v1/snapshot/exports/:filename`
  - Directory structure: `snapshots/exports/` with .keep file
  - All smoke tests passed (102 links exported, temp links excluded, security verified)

- ✅ **Phase 3: Import System** - COMPLETE
  - Import service with transaction safety and dual-mode handling (skip/update)
  - Rake task: `snapshot:import[file,mode]`
  - API endpoint: `POST /api/v1/snapshot/import`
  - Case-insensitive tag matching, URL normalization delegation
  - All smoke tests passed (skip mode, update mode, error handling, transaction rollback)

**In progress:**
- 🔄 **Phase 4: Testing & Validation** - Ready to begin

**Not started:**
- ⬜ **Phase 5: Documentation**

Next step: Begin Phase 4 - Testing & Validation (create RSpec tests for Import Service)

