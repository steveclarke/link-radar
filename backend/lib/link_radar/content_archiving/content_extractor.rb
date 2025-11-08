# frozen_string_literal: true

module LinkRadar
  module ContentArchiving
    # Value object for parsed content metadata
    #
    # Contains all metadata extracted from HTML content, including
    # OpenGraph, Twitter Cards, canonical URL, and context about
    # where the content came from.
    ContentMetadata = Data.define(
      :opengraph,      # OpenGraph metadata hash (or nil)
      :twitter,        # Twitter Card metadata hash (or nil)
      :canonical_url,  # Canonical URL string (or nil)
      :final_url,      # Final URL after redirects (source URL)
      :content_type    # Content type (always "html" for ContentExtractor)
    )

    # Value object for parsed web content
    ParsedContent = Data.define(
      :content_html,   # Main content as sanitized HTML string (XSS-safe)
      :content_text,   # Main content as plain text string
      :title,          # Page title string (or nil)
      :description,    # Page description string (or nil)
      :image_url,      # Featured image URL string (or nil)
      :metadata        # ContentMetadata instance
    )

    # Value object for extraction errors
    #
    # Provides structured error information from ContentExtractor.
    #
    # @example Extraction error
    #   error = ExtractionError.new(
    #     error_code: :extraction_error,
    #     error_message: "Failed to parse HTML",
    #     url: "https://example.com/article"
    #   )
    ExtractionError = Data.define(
      :error_code,      # Symbol: :extraction_error
      :error_message,   # String: human-readable error message
      :url,             # String: the URL being extracted
      :details          # Hash: additional context (optional)
    ) do
      def initialize(error_code:, error_message:, url:, details: {})
        super
      end
    end

    # Extracts content and metadata from HTML using multiple strategies
    #
    # Automatically sanitizes all HTML output to remove XSS vectors.
    #
    # Orchestrates three operations:
    # 1. MetaInspector - Extracts OpenGraph/Twitter Card metadata
    # 2. Ruby-Readability - Extracts main article content (Mozilla algorithm)
    # 3. Loofah - Sanitizes HTML to remove XSS vectors
    #
    # Also extracts plain text version for full-text search and LLM embeddings.
    #
    # @example Extracting from HTML
    #   result = ContentExtractor.new(
    #     html: "<html>...</html>",
    #     url: "https://example.com/article"
    #   ).call
    #
    #   parsed = result.data # => ParsedContent instance
    #   parsed.title              # => "Article Title"
    #   parsed.content_html       # => "<div>Article content...</div>"
    #   parsed.metadata.opengraph # => {"title" => "...", "image" => "..."}
    #
    class ContentExtractor
      include LinkRadar::Resultable

      # @param html [String] the HTML content to extract from
      # @param url [String] the source URL (used for relative URL resolution)
      def initialize(html:, url:)
        @html = html
        @url = url
      end

      # Extracts content and metadata from HTML
      #
      # @return [LinkRadar::Result] success with ParsedContent or failure with ExtractionError
      def call
        # Extract metadata using MetaInspector
        metadata_result = extract_metadata
        return metadata_result if metadata_result.failure?

        # Extract main content using Readability
        content_result = extract_content
        return content_result if content_result.failure?

        # Sanitize extracted HTML to remove XSS vectors
        sanitization_result = sanitize_html(content_result.data[:content_html])
        return sanitization_result if sanitization_result.failure?

        # Combine results into ParsedContent value object
        success(
          ParsedContent.new(
            content_html: sanitization_result.data,
            content_text: content_result.data[:content_text],
            title: metadata_result.data[:title],
            description: metadata_result.data[:description],
            image_url: metadata_result.data[:image_url],
            metadata: metadata_result.data[:metadata]
          )
        )
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Content extraction error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      private

      attr_reader :html, :url

      # Extracts metadata using MetaInspector
      #
      # Priority order for title/description:
      # 1. OpenGraph (og:title, og:description)
      # 2. Twitter Card (twitter:title, twitter:description)
      # 3. HTML meta tags (<title>, <meta name="description">)
      #
      # @return [LinkRadar::Result] success with metadata or failure with ExtractionError
      def extract_metadata
        # MetaInspector expects to fetch the page itself, but we already have HTML
        # Use document: option to provide pre-fetched HTML
        page = MetaInspector.new(url, document: html, warn_level: :store)

        success(
          title: extract_title(page),
          description: extract_description(page),
          image_url: extract_image(page),
          metadata: build_metadata(page)
        )
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Metadata extraction error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Extracts main content using Ruby-Readability
      #
      # Readability strips ads, navigation, footers, and extracts the main
      # article content. Also generates plain text version for search.
      #
      # @return [LinkRadar::Result] success with content or failure with ExtractionError
      def extract_content
        doc = Readability::Document.new(html, tags: %w[div p article section])

        content_html = doc.content
        content_text = extract_text_from_html(content_html)

        success(
          content_html: content_html,
          content_text: content_text
        )
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Content extraction error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Extracts title with fallback priority
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [String, nil] extracted title
      def extract_title(page)
        page.best_title || page.title
      end

      # Extracts description with fallback priority
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [String, nil] extracted description
      def extract_description(page)
        page.best_description || page.description
      end

      # Extracts preview image URL
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [String, nil] image URL
      def extract_image(page)
        page.images.best
      end

      # Builds ContentMetadata value object
      #
      # Includes OpenGraph, Twitter Card, canonical URL, plus context
      # about where the content came from (final_url, content_type).
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [ContentMetadata] structured metadata value object with all fields
      def build_metadata(page)
        ContentMetadata.new(
          opengraph: extract_opengraph(page),
          twitter: extract_twitter_card(page),
          canonical_url: page.meta_tags["canonical"]&.first,
          final_url: url,
          content_type: "html"
        )
      end

      # Extracts OpenGraph metadata
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [Hash, nil] OpenGraph data or nil if not present
      def extract_opengraph(page)
        og_data = {}
        %w[title description image type url].each do |key|
          value = page.meta_tags["og:#{key}"]&.first
          og_data[key] = value if value
        end
        og_data.presence
      end

      # Extracts Twitter Card metadata
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [Hash, nil] Twitter Card data or nil if not present
      def extract_twitter_card(page)
        twitter_data = {}
        %w[card title description image].each do |key|
          value = page.meta_tags["twitter:#{key}"]&.first
          twitter_data[key] = value if value
        end
        twitter_data.presence
      end

      # Sanitizes HTML content to remove XSS vectors
      #
      # Uses Loofah to strip dangerous elements and attributes:
      # - Script tags and inline JavaScript
      # - Event handlers (onclick, onload, etc.)
      # - Dangerous attributes (style with javascript:, etc.)
      # - Other XSS attack vectors
      #
      # Preserves safe HTML structure for display purposes.
      #
      # @param html [String] the HTML content to sanitize
      # @return [LinkRadar::Result] success with sanitized HTML or failure with ExtractionError
      def sanitize_html(html)
        sanitized = Loofah.fragment(html).scrub!(:prune).to_s
        success(sanitized)
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "HTML sanitization error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Extracts plain text from HTML for search indexing
      #
      # Uses Nokogiri to properly parse HTML and extract text content.
      # This handles script/style removal, HTML entities (&amp; → &),
      # and all edge cases that regex cannot handle correctly.
      #
      # @param html [String] the HTML content
      # @return [String] plain text content
      def extract_text_from_html(html)
        text = Nokogiri::HTML(html).text
        text.gsub(/\s+/, " ").strip
      end
    end
  end
end
