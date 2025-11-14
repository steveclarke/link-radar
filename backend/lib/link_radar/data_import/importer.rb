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

      # Import directory path (Docker volume compatible)
      IMPORT_DIR = Rails.root.join("snapshots/imports")

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
