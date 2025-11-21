# frozen_string_literal: true

module LinkRadar
  module Ai
    # Analyzes page content using AI and suggests relevant tags and notes
    #
    # This service orchestrates AI-powered content analysis:
    # 1. Validates input (URL not private/localhost, content length, required fields)
    # 2. Fetches user's existing tags for context
    # 3. Calls configured LLM via RubyLLM with structured JSON output
    # 4. Performs two-stage tag matching (AI suggests, backend verifies existence)
    # 5. Returns structured response with suggested note and tags
    #
    # The service is stateless - RubyLLM.chat conversations are not persisted,
    # and we don't save anything to the database. Pure request/response.
    #
    # Uses existing UrlValidator for SSRF protection (blocks localhost/private IPs).
    # Sends tag names to AI (alphabetically, limit 5000) for taxonomy consistency.
    # Case-insensitive tag verification ensures accurate "exists" flags.
    #
    # @example
    #   result = LinkAnalyzer.new(
    #     url: "https://example.com/article",
    #     content: "Article text...",
    #     title: "Article Title"
    #   ).call
    #
    #   if result.success?
    #     result.data[:suggested_note]  # => "Brief explanation..."
    #     result.data[:suggested_tags]  # => [{name: "Ruby", exists: true}, ...]
    #   else
    #     result.errors  # => ["URL resolves to private IP..."]
    #   end
    #
    class LinkAnalyzer
      include LinkRadar::Resultable

      # Maximum allowed content length (50,000 characters)
      MAX_CONTENT_LENGTH = 50_000

      # @param url [String] page URL
      # @param content [String] main text content to analyze
      # @param title [String] page title
      # @param description [String, nil] page description
      # @param author [String, nil] author name
      def initialize(url:, content:, title:, description: nil, author: nil)
        @url = url
        @content = content
        @title = title
        @description = description
        @author = author
      end

      # Performs AI analysis and returns structured suggestions
      #
      # @return [LinkRadar::Result] success with suggestion hash or failure with error messages
      def call
        validate_inputs!

        ai_response = call_llm
        build_response(ai_response)
      rescue ArgumentError => e
        # Validation errors (private IP, content too long, missing fields)
        failure(e.message)
      rescue => e
        # LLM API errors, network errors, JSON parse errors
        Rails.logger.error("AI analysis failed: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        failure("AI analysis failed. Please try again.")
      end

      private

      attr_reader :url, :content, :title, :description, :author

      # Validates all input parameters
      #
      # Checks:
      # - Required fields present (url, title)
      # - URL is valid HTTP/HTTPS
      # - URL is not localhost or private IP (SSRF protection)
      # - Content length within limits
      #
      # @raise [ArgumentError] if validation fails
      def validate_inputs!
        raise ArgumentError, "URL is required" if url.blank?
        raise ArgumentError, "Title is required" if title.blank?

        # Validate URL format and privacy (uses existing UrlValidator)
        validate_url_safe!

        # Validate content length (backend safety check)
        if content.length > MAX_CONTENT_LENGTH
          raise ArgumentError, "Content exceeds maximum length of #{MAX_CONTENT_LENGTH} characters"
        end
      end

      # Validates URL using existing UrlValidator (SSRF protection)
      #
      # Uses the same validation logic as the content archiving feature.
      # Blocks localhost, private IPs, and invalid URL formats.
      #
      # @raise [ArgumentError] if URL validation fails
      def validate_url_safe!
        result = LinkRadar::ContentArchiving::UrlValidator.new(url).call

        if result.failure?
          raise ArgumentError, result.errors.first
        end
      end

      # Memoized existing tag names for AI context
      #
      # Fetches tags on first call and caches the result for the instance lifecycle.
      # Returns tags alphabetically ordered.
      # Limited by config as safety valve (default 5000, effectively unlimited).
      #
      # @return [Array<String>] existing tag names
      def existing_tags
        @existing_tags ||= Tag.order(:name)
          .limit(LlmConfig.max_tags_for_analysis)
          .pluck(:name)
      end

      # Calls configured LLM via RubyLLM with structured output
      #
      # Uses RubyLLM's chat interface with schema for structured output.
      # The schema ensures reliable JSON parsing and type safety.
      # Model is configured via LlmConfig.analysis_model.
      # Uses memoized existing_tags for prompt context.
      #
      # @return [Hash] parsed AI response with "note" and "tags" keys
      # @raise [StandardError] if API call fails or response is invalid
      def call_llm
        prompt = build_prompt

        chat = RubyLLM.chat(model: LlmConfig.analysis_model)
        chat.with_instructions(
          "You are a helpful assistant that analyzes web content and suggests tags and notes for organizing saved links."
        )

        response = chat.with_schema(LinkRadar::Ai::LinkAnalysisSchema).ask(prompt)

        # Response content is automatically parsed from JSON by RubyLLM::Schema
        response.content
      rescue => e
        Rails.logger.error("LLM API call failed: #{e.class} - #{e.message}")
        raise StandardError, "AI analysis service unavailable"
      end

      # Builds the AI prompt with content and existing tags context
      #
      # Prompt strategy:
      # - Provides full content metadata (title, description, author, URL)
      # - Includes main article text
      # - Lists existing tags to encourage reuse
      # - Instructs AI on format, tone, and tag preferences
      #
      # @return [String] formatted prompt
      def build_prompt
        # Build context sections
        metadata_section = build_metadata_section
        existing_tags_section = build_existing_tags_section

        <<~PROMPT
          You are helping a user organize web content they want to save for later.

          Analyze this content and suggest:
          1. A brief note (1-2 sentences) explaining why it's worth saving
          2. Relevant tags (3-7 tags) to categorize it

          CONTENT DETAILS:
          #{metadata_section}

          MAIN CONTENT:
          #{content}

          #{existing_tags_section}

          INSTRUCTIONS:
          - Note should be casual and conversational (if any tone is applied)
          - Prefer using existing tags when relevant (but don't force-fit tags that don't apply)
          - Be liberal with tags - capture nuances without artificial constraints
          - Use Title Case for new tags (e.g., "JavaScript" not "javascript")
          - Don't suggest obvious synonyms if existing tag exists (e.g., don't suggest "js" if "JavaScript" exists)
          - Suggest 3-7 tags based purely on content relevance (flexible based on content complexity)
        PROMPT
      end

      # Builds metadata section of prompt
      #
      # @return [String] formatted metadata for prompt
      def build_metadata_section
        parts = ["Title: #{title}"]
        parts << "Description: #{description}" if description.present?
        parts << "Author: #{author}" if author.present?
        parts << "URL: #{url}"
        parts.join("\n")
      end

      # Builds existing tags section of prompt
      #
      # Uses memoized existing_tags from the instance.
      #
      # @return [String] formatted existing tags context for prompt
      def build_existing_tags_section
        if existing_tags.any?
          "EXISTING TAGS:\nThe user already has these tags: #{existing_tags.join(", ")}"
        else
          "EXISTING TAGS:\nThe user has no existing tags yet."
        end
      end

      # Builds final response with tag existence verification
      #
      # Two-stage tag matching:
      # 1. AI receives existing tags and naturally gravitates toward them
      # 2. Backend verifies each suggestion against database (case-insensitive)
      #
      # This ensures the "exists" flag is 100% accurate regardless of AI behavior.
      # Uses memoized existing_tags from the instance.
      #
      # @param ai_response [Hash] parsed AI response with "note" and "tags" keys
      # @return [LinkRadar::Result] success with structured suggestion data
      def build_response(ai_response)
        # Build case-insensitive lookup for O(1) matching
        existing_tags_downcase = existing_tags.map(&:downcase).to_set

        # Verify each AI suggestion against existing tags
        suggested_tags = ai_response["tags"].map do |tag_name|
          {
            name: tag_name,
            exists: existing_tags_downcase.include?(tag_name.downcase)
          }
        end

        success(
          suggested_note: ai_response["note"],
          suggested_tags: suggested_tags
        )
      end
    end
  end
end
