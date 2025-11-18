# frozen_string_literal: true

module LinkRadar
  module ContentArchiving
    # Orchestrates the complete content archival pipeline
    #
    # This service coordinates the full archival workflow:
    # 1. Transitions to processing state
    # 2. Fetches content via HttpFetcher (returns FetchedContent value object)
    # 3. Classifies content type (HTML vs PDF/image/etc)
    # 4. Routes to appropriate processor (HTML extraction or metadata-only)
    # 5. Stores results and transitions to completed/failed
    #
    # The Archiver handles ALL business logic for archival:
    # - State machine transitions
    # - Error classification and mapping
    # - Content type detection and routing
    # - Result persistence
    #
    # Value Objects Used:
    # - FetchedContent: Returned by HttpFetcher on success (content_type, body, final_url)
    # - FetchError: Returned by HttpFetcher on failure (error_code, error_message, http_status)
    # - ParsedContent: Returned by ContentExtractor on success (title, description, content_html, etc.)
    # - ExtractionError: Returned by ContentExtractor on failure (error_code, error_message)
    #
    # @example Success case
    #   archiver = Archiver.new(archive: archive)
    #   result = archiver.call
    #   result.success? # => true
    #   archive.current_state # => "completed"
    #
    # @example Failure case
    #   archiver = Archiver.new(archive: archive)
    #   result = archiver.call
    #   result.failure? # => true
    #   result.errors # => ["URL resolves to private IP..."]
    #   archive.current_state # => "failed"
    #
    class Archiver
      include LinkRadar::Resultable

      # @param archive [ContentArchive] the archive record to populate (includes link association)
      # @param config [ContentArchiveConfig] optional config (defaults to new instance)
      def initialize(archive:, config: nil)
        @archive = archive
        @link = archive.link  # Get link from the association
        @config = config || ContentArchiveConfig.new
      end

      # Executes the archival pipeline
      #
      # @return [LinkRadar::Result] success or failure with error details
      def call
        # Defensive check: ensure archival is still enabled
        # Primary check happens in Link callback, but this catches edge cases:
        # - Configuration changed between job enqueue and execution
        # - Jobs manually enqueued when they shouldn't be
        # - Race conditions during configuration updates
        unless config.enabled
          handle_archival_disabled
          return failure("Content archival disabled")
        end

        # Transition to processing state
        archive.transition_to!(:processing)

        # Execute the archival pipeline
        execute_pipeline
      rescue => e
        handle_unexpected_error(e)
      end

      private

      attr_reader :link, :archive, :config

      # Executes the core archival pipeline
      #
      # Pipeline steps:
      # 1. Fetch content (HttpFetcher validates URL internally)
      # 2. Check if fetch succeeded
      # 3. Classify content type (HTML vs non-HTML)
      # 4. Route to appropriate processor
      #
      # @return [LinkRadar::Result] success or failure
      def execute_pipeline
        # Step 1: Fetch content
        # HttpFetcher validates URL internally (initial URL + all redirects)
        # Returns FetchedContent value object on success
        fetch_result = HttpFetcher.new(link.url).call

        # Step 2: Handle fetch failure
        if fetch_result.failure?
          handle_fetch_failure(fetch_result)
          return fetch_result
        end

        # Step 3 & 4: Classify and process content
        fetched_content = fetch_result.data # FetchedContent value object
        if html_content?(fetched_content.content_type)
          process_html_content(fetched_content)
        else
          process_binary_content(fetched_content)
        end
      end

      # Handles archival being globally disabled
      #
      # @return [LinkRadar::Result] failure result
      def handle_archival_disabled
        ActiveRecord::Base.transaction do
          archive.transition_to!(
            :failed,
            error_reason: "disabled",
            error_message: "Content archival disabled"
          )
          archive.update!(error_message: "Content archival disabled")
        end
        failure("Content archival disabled")
      end

      # Handles HTTP fetch failures (includes validation failures from HttpFetcher)
      #
      # HttpFetcher and UrlValidator return structured FetchError value objects
      # with error_code already classified, so we can use it directly.
      #
      # @param result [LinkRadar::Result] the failed fetch result
      # @return [LinkRadar::Result] the failure result
      def handle_fetch_failure(result)
        error = result.data # FetchError value object

        # Use structured error data from FetchError
        ActiveRecord::Base.transaction do
          archive.transition_to!(
            :failed,
            error_reason: error.error_code.to_s,
            error_message: error.error_message,
            http_status: error.http_status
          )
          archive.update!(error_message: error.error_message)
        end
        result
      end

      # Handles content extraction failures
      #
      # ContentExtractor returns structured ExtractionError value objects
      # with error_code already set.
      #
      # @param result [LinkRadar::Result] the failed extraction result
      # @return [LinkRadar::Result] the failure result
      def handle_extraction_failure(result)
        error = result.data # ExtractionError value object

        ActiveRecord::Base.transaction do
          archive.transition_to!(
            :failed,
            error_reason: error.error_code.to_s,
            error_message: error.error_message
          )
          archive.update!(error_message: error.error_message)
        end
        result
      end

      # Handles unexpected errors during archival
      #
      # @param error [StandardError] the unexpected error
      # @return [LinkRadar::Result] failure result
      def handle_unexpected_error(error)
        error_message = "Unexpected error: #{error.class} - #{error.message}"

        Rails.logger.error "ContentArchive #{archive.id} error: #{error_message}"
        Rails.logger.error error.backtrace.join("\n")

        ActiveRecord::Base.transaction do
          archive.transition_to!(
            :failed,
            error_reason: "unexpected_error",
            error_message: error_message
          )
          archive.update!(error_message: error_message)
        end
        failure(error_message)
      end

      # Checks if content type is HTML
      #
      # Phase 1 supports only HTML content for full extraction.
      # Other content types (PDF, images, etc.) are stored with metadata only.
      #
      # @param content_type [String] the Content-Type header value
      # @return [Boolean] true if HTML, false otherwise
      def html_content?(content_type)
        return false if content_type.blank?

        content_type.downcase.include?("text/html") ||
          content_type.downcase.include?("application/xhtml+xml")
      end

      # Processes HTML content through the full extraction pipeline
      #
      # Pipeline:
      # 1. Extract content and metadata via ContentExtractor
      # 2. Store extracted content (already sanitized by ContentExtractor)
      # 3. Store metadata (complete from ContentExtractor)
      # 4. Transition to completed
      #
      # @param fetched_content [FetchedContent] the fetched content value object
      # @return [LinkRadar::Result] success or failure
      def process_html_content(fetched_content)
        # Extract content and metadata (returns ParsedContent value object)
        # NOTE: ContentExtractor automatically sanitizes HTML output for XSS protection
        extraction_result = ContentExtractor.new(
          html: fetched_content.body,
          url: fetched_content.final_url
        ).call

        return handle_extraction_failure(extraction_result) if extraction_result.failure?

        parsed = extraction_result.data # ParsedContent instance

        # Store results and transition to completed in a transaction
        # ContentMetadata already includes final_url and content_type, so just convert to hash
        ActiveRecord::Base.transaction do
          archive.update!(
            content_html: parsed.content_html, # Already XSS-safe from ContentExtractor
            content_text: parsed.content_text,
            title: parsed.title,
            description: parsed.description,
            image_url: parsed.image_url,
            metadata: parsed.metadata.to_h,  # ContentMetadata → Hash (includes final_url, content_type)
            fetched_at: Time.current
          )

          # Transition to completed
          archive.transition_to!(:completed)
        end

        Rails.logger.info "ContentArchive #{archive.id} completed (HTML)"
        success(archive)
      end

      # Processes non-HTML content (PDFs, images, videos, etc.)
      #
      # Phase 1: Store basic metadata only (raw MIME type + URL)
      # Future: Add PDF text extraction, image processing, etc.
      #
      # Just stores what we received from HttpFetcher without transformation.
      # Content type classification is a presentation concern, not archival logic.
      #
      # Pipeline:
      # 1. Store metadata from fetch result (no content extraction)
      # 2. Transition to completed
      #
      # @param fetched_content [FetchedContent] the fetched content value object
      # @return [LinkRadar::Result] success
      def process_binary_content(fetched_content)
        content_type = fetched_content.content_type
        final_url = fetched_content.final_url

        # Store metadata and transition to completed in a transaction
        ActiveRecord::Base.transaction do
          archive.update!(
            metadata: {
              content_type: content_type,  # Raw MIME type (e.g., "application/pdf", "image/jpeg")
              final_url: final_url
            },
            fetched_at: Time.current
          )

          # Transition to completed
          archive.transition_to!(:completed)
        end

        Rails.logger.info "ContentArchive #{archive.id} completed (#{content_type})"
        success(archive)
      end
    end
  end
end
