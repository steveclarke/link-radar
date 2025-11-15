# frozen_string_literal: true

module LinkRadar
  module Snapshot
    # Exports all links to JSON file with reserved tag filtering
    #
    # This service handles the complete export workflow:
    # 1. Query all links with eager-loaded tags
    # 2. Filter out links tagged with ~temp~ (test/temporary data)
    # 3. Serialize to nested JSON format (human-readable, denormalized)
    # 4. Generate timestamped filename with UUID (unguessable for security)
    # 5. Write to snapshot/exports/ directory
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
    #     puts result.data[:file_path]  # => "snapshot/exports/linkradar-export-2025-11-12-143022-uuid.json"
    #     puts result.data[:link_count] # => 42
    #   end
    #
    class Exporter
      include LinkRadar::Resultable

      # Export directory path (Docker volume compatible)
      EXPORT_DIR = Rails.root.join(CoreConfig.snapshot_exports_dir)

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
