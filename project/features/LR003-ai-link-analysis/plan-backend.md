# LR003 - AI-Powered Link Analysis: Backend Implementation Plan

## Overview

This plan implements the backend API endpoint for AI-powered link analysis using OpenAI via RubyLLM. The feature provides intelligent tag and note suggestions based on page content extracted by the browser extension.

**Key Components:**
- Stateless analysis endpoint (no database persistence)
- AI integration via RubyLLM with structured JSON output
- Two-stage tag matching (AI guidance + backend verification)
- Privacy protection via existing UrlValidator (reuses SSRF protection)

**Sequencing Logic:**
1. Prerequisites first (confirm dependencies)
2. Core service layer (AI integration is the heart of this feature)
3. Controller and view (standard Rails API endpoint pattern)
4. Testing (verify behavior with mocked OpenAI calls)

**References:**
- Technical Spec: [spec.md](spec.md) sections 3 (API), 4 (Backend), 9.4 (Testing)
- Requirements: [requirements.md](requirements.md) sections 4.1 (AI Rules), 7.2 (Backend Integration)
- Vision: [vision.md](vision.md) for feature context

## Table of Contents

1. [Phase 1: Prerequisites & Configuration Verification](#phase-1-prerequisites--configuration-verification)
2. [Phase 2: AI Analysis Service](#phase-2-ai-analysis-service)
3. [Phase 3: Controller & Route](#phase-3-controller--route)
4. [Phase 4: Jbuilder View](#phase-4-jbuilder-view)
5. [Phase 5: Testing](#phase-5-testing)

---

## Phase 1: Prerequisites & Configuration Verification

**Purpose:** Confirm all dependencies and configuration are in place before implementation.

**Justification:** Validates that RubyLLM, OpenAI configuration, and existing privacy protection utilities are ready. (spec.md#6.1, spec.md#7.1)

### Tasks

- [ ] Verify RubyLLM gem is installed (~> 1.8 in Gemfile.lock)
- [ ] Confirm `config/initializers/ruby_llm.rb` exists and loads OpenAI key from `LlmConfig.openai_api_key`
- [ ] Verify `OPENAI_API_KEY` is set in development `.env` file
- [ ] Confirm `LinkRadar::ContentArchiving::UrlValidator` exists and is available for reuse (reuses existing SSRF protection)
- [ ] Verify `Tag` model exists with `pluck(:name)` capability for fetching existing tag names

**Validation:** Run Rails console and confirm:
```ruby
LlmConfig.openai_api_key.present?
LinkRadar::ContentArchiving::UrlValidator.new("https://example.com").call.success?
Tag.pluck(:name)
```

---

## Phase 2: AI Analysis Service

**Purpose:** Implement the core AI integration service that analyzes page content and returns tag/note suggestions.

**Justification:** This is the heart of the feature - handles OpenAI communication, prompt engineering, structured output parsing, and tag matching logic. (spec.md#4.1, spec.md#4.2, spec.md#4.3)

### File: `lib/link_radar/ai/analyze_link_content.rb`

This service is **novel** - first use of OpenAI structured outputs in the codebase. Full implementation detail provided:

```ruby
# frozen_string_literal: true

module LinkRadar
  module AI
    # Analyzes page content using OpenAI and suggests relevant tags and notes
    #
    # This service orchestrates AI-powered content analysis:
    # 1. Validates input (URL not private/localhost, content length, required fields)
    # 2. Fetches user's existing tags for context
    # 3. Calls OpenAI GPT-4o-mini via RubyLLM with structured JSON output
    # 4. Performs two-stage tag matching (AI suggests, backend verifies existence)
    # 5. Returns structured response with suggested note and tags
    #
    # The service is stateless - no database persistence, pure request/response.
    #
    # Privacy: Reuses existing UrlValidator for SSRF protection (blocks localhost/private IPs)
    # AI Context: Sends existing tag names to AI to encourage consistent taxonomy
    # Tag Matching: Case-insensitive verification ensures accurate "exists" flags
    #
    # @example Basic usage
    #   service = AnalyzeLinkContent.new(
    #     url: "https://example.com/article",
    #     content: "Article text...",
    #     title: "Article Title",
    #     description: "Article description",
    #     author: "Author Name"
    #   )
    #   result = service.call
    #   
    #   if result.success?
    #     result.data[:suggested_note]  # => "Brief explanation of content value"
    #     result.data[:suggested_tags]  # => [{name: "Ruby", exists: true}, ...]
    #   else
    #     result.errors  # => ["URL resolves to private IP..."]
    #   end
    #
    # @example Error handling
    #   result = service.call
    #   if result.failure?
    #     case result.errors.first
    #     when /private IP/
    #       # Privacy violation
    #     when /Content exceeds/
    #       # Content too long
    #     when /AI analysis failed/
    #       # OpenAI API error
    #     end
    #   end
    #
    class AnalyzeLinkContent
      include LinkRadar::Resultable

      # Maximum allowed content length (50,000 characters)
      # Extension should truncate before sending, this is a safety check
      MAX_CONTENT_LENGTH = 50_000

      # JSON schema for OpenAI structured output
      # Ensures reliable parsing and type safety from AI responses
      ANALYSIS_SCHEMA = {
        type: "object",
        properties: {
          note: {
            type: "string",
            description: "1-2 sentence note explaining why content is worth saving"
          },
          tags: {
            type: "array",
            description: "Relevant tags for the content (typically 3-7)",
            items: {
              type: "string"
            }
          }
        },
        required: ["note", "tags"]
      }.freeze

      # @param url [String] page URL (must be HTTP/HTTPS)
      # @param content [String] main article text from Readability
      # @param title [String] page title (required)
      # @param description [String, nil] meta description (optional)
      # @param author [String, nil] author info (optional)
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
        
        existing_tags = fetch_existing_tags
        ai_response = call_openai(existing_tags)
        build_response(ai_response, existing_tags)
      rescue ArgumentError => e
        # Validation errors (private IP, content too long, missing fields)
        failure(e.message)
      rescue => e
        # OpenAI API errors, network errors, JSON parse errors
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

        # Validate URL format and privacy (reuses existing UrlValidator)
        validate_url_safe!

        # Validate content length (backend safety check)
        if content.length > MAX_CONTENT_LENGTH
          raise ArgumentError, "Content exceeds maximum length of #{MAX_CONTENT_LENGTH} characters"
        end
      end

      # Validates URL using existing UrlValidator (SSRF protection)
      #
      # This reuses the same validation logic as content archiving feature.
      # Blocks localhost, private IPs, and invalid URL formats.
      #
      # @raise [ArgumentError] if URL validation fails
      def validate_url_safe!
        result = LinkRadar::ContentArchiving::UrlValidator.new(url).call
        
        if result.failure?
          raise ArgumentError, result.errors.first
        end
      end

      # Fetches all existing tag names for the current user
      #
      # Returns array of tag names (strings) sorted alphabetically.
      # Used as context for AI to encourage consistent tag suggestions.
      #
      # @return [Array<String>] existing tag names
      def fetch_existing_tags
        Tag.order(:name).pluck(:name)
      end

      # Calls OpenAI API via RubyLLM with structured output
      #
      # Constructs prompt with content and existing tags context.
      # Uses GPT-4o-mini for cost-effectiveness.
      # Enforces JSON schema for reliable response parsing.
      #
      # @param existing_tags [Array<String>] user's existing tag names
      # @return [Hash] parsed AI response with :note and :tags keys
      # @raise [StandardError] if API call fails or response is invalid
      def call_openai(existing_tags)
        prompt = build_prompt(existing_tags)
        
        response = RubyLLM::Messages.create(
          model: "gpt-4o-mini",
          messages: [
            { 
              role: "system", 
              content: "You are a helpful assistant that analyzes web content and suggests tags and notes for organizing saved links."
            },
            { role: "user", content: prompt }
          ],
          response_format: {
            type: "json_schema",
            json_schema: {
              name: "link_analysis",
              schema: ANALYSIS_SCHEMA,
              strict: true
            }
          }
        )
        
        # Parse the structured JSON response
        content = response.choices.first.message.content
        JSON.parse(content)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
        Rails.logger.error("Response content: #{content}")
        raise StandardError, "AI returned invalid response format"
      rescue => e
        Rails.logger.error("OpenAI API call failed: #{e.class} - #{e.message}")
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
      # @param existing_tags [Array<String>] user's existing tag names
      # @return [String] formatted prompt for OpenAI
      def build_prompt(existing_tags)
        # Build context sections
        metadata_section = build_metadata_section
        existing_tags_section = build_existing_tags_section(existing_tags)
        
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
      # @param existing_tags [Array<String>] user's existing tag names
      # @return [String] formatted existing tags context for prompt
      def build_existing_tags_section(existing_tags)
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
      #
      # @param ai_response [Hash] parsed AI response with :note and :tags
      # @param existing_tags [Array<String>] user's existing tag names
      # @return [LinkRadar::Result] success with structured suggestion data
      def build_response(ai_response, existing_tags)
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
```

### Tasks

- [ ] Create directory `lib/link_radar/ai/` if it doesn't exist
- [ ] Create `lib/link_radar/ai/analyze_link_content.rb` with full service implementation above
- [ ] Verify service follows `LinkRadar::Resultable` pattern (returns `success(data)` or `failure(errors)`)
- [ ] Ensure YARD documentation is complete for all public methods
- [ ] Verify MAX_CONTENT_LENGTH constant matches spec (50,000 characters per spec.md#3.2)
- [ ] Confirm ANALYSIS_SCHEMA matches OpenAI structured output requirements

**Key Implementation Notes:**
- **Privacy:** Reuses `LinkRadar::ContentArchiving::UrlValidator` for SSRF protection (no new code needed)
- **Stateless:** No database writes, pure transformation service
- **Two-Stage Matching:** AI receives tags as guidance, backend verifies existence accurately
- **Error Handling:** ArgumentError for validation, StandardError for AI failures, all logged with context

---

## Phase 3: Controller & Route

**Purpose:** Add the analyze endpoint to LinksController and configure routing.

**Justification:** Exposes the AI analysis service via REST API following existing controller patterns. (spec.md#3.1, spec.md#4.1)

### File: `app/controllers/api/v1/links_controller.rb`

Add analyze action to existing controller (follows pattern from `by_url` action):

```ruby
# POST /api/v1/links/analyze
# Analyzes page content and returns AI-generated tag and note suggestions
def analyze
  result = LinkRadar::AI::AnalyzeLinkContent.new(
    url: params[:url],
    content: params[:content],
    title: params[:title],
    description: params[:description],
    author: params[:author]
  ).call
  
  if result.success?
    @suggested_note = result.data[:suggested_note]
    @suggested_tags = result.data[:suggested_tags]
    render :analyze
  else
    # Error handling via ErrorHandlers concern (existing pattern)
    # ArgumentError triggers 400/422, StandardError triggers 500
    raise ArgumentError, result.errors.first
  end
end
```

### File: `config/routes.rb`

Add analyze route to links resources (follows pattern from `by_url` route):

```ruby
namespace :api do
  namespace :v1 do
    resources :links do
      collection do
        get :by_url
        post :analyze    # NEW: AI analysis endpoint
      end
    end
  end
end
```

### Tasks

- [ ] Add `analyze` action to `Api::V1::LinksController` (follow pattern from `by_url` action at line 21-27)
- [ ] Add `post :analyze` route to `config/routes.rb` under links collection routes
- [ ] Verify error handling works via `ErrorHandlers` concern (no custom error handling needed)
- [ ] Confirm authentication via `before_action :authenticate_api_request!` applies to analyze action
- [ ] Test route is registered: `rails routes | grep analyze` should show `POST /api/v1/links/analyze`

**Pattern Reference:** Follow existing controller action pattern from `by_url` (lines 21-27) - same structure: call service, handle result, render view or raise error.

---

## Phase 4: Jbuilder View

**Purpose:** Create JSON view template for analyze endpoint response.

**Justification:** Returns structured suggestion data following existing API response format patterns. (spec.md#3.3)

### File: `app/views/api/v1/links/analyze.jbuilder`

```ruby
# API response for link analysis
# Returns AI-generated suggestions for tags and notes
#
# Response format matches spec.md#3.3:
# {
#   data: {
#     suggested_note: String,
#     suggested_tags: [{name: String, exists: Boolean}]
#   }
# }
json.data do
  json.suggested_note @suggested_note
  json.suggested_tags @suggested_tags do |tag|
    json.name tag[:name]
    json.exists tag[:exists]
  end
end
```

### Tasks

- [ ] Create directory `app/views/api/v1/links/` if it doesn't exist
- [ ] Create `analyze.jbuilder` view with structure above
- [ ] Verify response format matches spec.md#3.3 (data wrapper with suggested_note and suggested_tags)
- [ ] Confirm tag structure includes both `name` and `exists` fields
- [ ] Test JSON output structure manually via curl or Bruno

**Pattern Reference:** Follow existing jbuilder views (e.g., `show.jbuilder`) - use `json.data` wrapper and iterate arrays with block syntax.

---

## Phase 5: Testing

**Purpose:** Verify AI analysis service and API endpoint behavior with mocked OpenAI calls.

**Justification:** Ensures reliability without hitting OpenAI API constantly. Tests validation, tag matching, error handling, and response format. (spec.md#8, requirements.md#8)

### Test Strategy

**WebMock for OpenAI:** Mock all OpenAI API calls using WebMock to avoid:
- Hitting API during test runs (cost, speed, reliability)
- Dependency on external service availability
- Non-deterministic AI responses

**Focus Areas:**
- Input validation (URL, content length, required fields)
- Privacy protection (localhost/private IPs blocked)
- Tag matching logic (case-insensitive, exists flag accuracy)
- Error scenarios (API failures, timeouts, invalid responses)
- Response format (matches spec contract)

**Manual Quality Assessment:** AI suggestion quality is subjective - verify manually during development, not in automated tests.

### File: `spec/lib/link_radar/ai/analyze_link_content_spec.rb`

**Spec Outline:**

```ruby
require "rails_helper"

RSpec.describe LinkRadar::AI::AnalyzeLinkContent do
  # Setup: Mock OpenAI API calls with WebMock
  # - Stub RubyLLM::Messages.create to return canned responses
  # - Create factory for valid AI response JSON
  # - Mock Tag.pluck(:name) to return existing tags

  describe "#call" do
    context "successful analysis" do
      # - Returns success Result object
      # - Includes suggested_note string
      # - Includes suggested_tags array
      # - Tags have name and exists attributes
      # - Existing tags marked with exists: true
      # - New tags marked with exists: false
    end

    context "input validation" do
      # - Missing URL raises ArgumentError
      # - Missing title raises ArgumentError
      # - Content exceeding 50,000 chars raises ArgumentError
      # - Invalid URL format rejected via UrlValidator
    end

    context "privacy protection" do
      # - Localhost URLs rejected (http://localhost, http://127.0.0.1)
      # - Private IP URLs rejected (http://192.168.1.1, http://10.0.0.1)
      # - Uses existing UrlValidator (verify via mock/spy)
    end

    context "tag matching logic" do
      # - Case-insensitive matching ("javascript" matches "JavaScript")
      # - Exact name matching only (no partial matches)
      # - Multiple existing tags correctly identified
      # - Mixed existing and new tags handled correctly
    end

    context "OpenAI API errors" do
      # - Network timeout returns failure with friendly error
      # - API rate limit returns failure
      # - Invalid JSON response returns failure
      # - Schema validation failure returns failure
      # - All errors logged with full context
    end

    context "prompt construction" do
      # - Includes content, title, URL in prompt
      # - Includes description when present
      # - Includes author when present
      # - Lists existing tags in prompt
      # - Handles empty existing tags list
    end
  end
end
```

### File: `spec/requests/api/v1/links/analyze_spec.rb`

**Spec Outline:**

```ruby
require "rails_helper"

describe "API: Analyze Link Content" do
  # Setup: Mock service layer to avoid OpenAI calls in request specs
  # - Stub LinkRadar::AI::AnalyzeLinkContent to return success/failure
  # - Use shared_context "with authenticated request"

  context "when unauthenticated" do
    # Use shared_example "authentication required"
    it_behaves_like "authentication required", :post, "/api/v1/links/analyze"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful analysis" do
      # - Returns 200 OK
      # - Response has data.suggested_note
      # - Response has data.suggested_tags array
      # - Tags have name and exists fields
      # - Response matches jbuilder structure
    end

    describe "validation errors" do
      # - Missing URL returns 400 with error message
      # - Missing title returns 400 with error message
      # - Content too long returns 422 with error message
      # - Private IP URL returns 400 with error message
    end

    describe "AI service errors" do
      # - Service failure returns 500 with generic error
      # - Error message doesn't expose internal details
      # - Response follows ErrorHandlers concern format
    end
  end
end
```

### Tasks

- [ ] Create `spec/lib/link_radar/ai/` directory
- [ ] Create `analyze_link_content_spec.rb` with spec outline above
- [ ] Create `spec/requests/api/v1/links/analyze_spec.rb` with spec outline above
- [ ] Implement WebMock stubs for RubyLLM::Messages.create (follow pattern from `http_fetcher_spec.rb` lines 28-29)
- [ ] Create shared factory for valid AI response JSON (note + tags array)
- [ ] Test all validation scenarios (URL, content length, required fields)
- [ ] Test privacy protection (localhost, private IPs)
- [ ] Test tag matching edge cases (case-insensitive, exists flag accuracy)
- [ ] Test error handling (API failures, invalid responses)
- [ ] Verify request spec uses `json_response` helper (spec/support/helpers/response_helpers.rb)
- [ ] Verify authentication spec uses shared examples (spec/support/shared_examples/authentication_required.rb)
- [ ] Run specs and confirm all pass: `rspec spec/lib/link_radar/ai/ spec/requests/api/v1/links/analyze_spec.rb`

**Testing Pattern References:**
- WebMock stubs: Follow `http_fetcher_spec.rb` pattern (lines 28-29: `stub_request(:get, url).to_return(...)`)
- Request specs: Follow `create_link_spec.rb` pattern (authenticated context, json_response helper, shared examples)
- Service specs: Follow Result pattern testing (`expect(result).to be_success`, `expect(result.data).to be_a(...)`)

---

## Implementation Complete

After completing all phases:

1. **Verify Integration:**
   - Test with Bruno or curl: `POST /api/v1/links/analyze` with sample content
   - Confirm response matches spec.md#3.3 format
   - Verify error handling (try localhost URL, content too long, etc.)

2. **Check Logs:**
   - Monitor `log/development.log` for AI API calls
   - Verify errors are logged with full context
   - Check OpenAI dashboard for API usage/costs

3. **Extension Integration:**
   - Backend is ready for extension to call
   - Extension will handle content extraction and send to this endpoint
   - See `plan-extension.md` for frontend implementation

**Success Criteria:**
- [ ] Endpoint accepts content and returns structured suggestions
- [ ] Existing tags correctly marked with `exists: true`
- [ ] New tags correctly marked with `exists: false`
- [ ] Privacy protection blocks localhost/private IPs
- [ ] Content length validation works (50K limit)
- [ ] Errors handled gracefully with appropriate status codes
- [ ] All specs pass

