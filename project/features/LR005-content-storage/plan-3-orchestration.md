# LR005 - Content Archival & Storage: Orchestration Plan

## Overview

This plan implements the archival orchestration service and background job that manages the content archival pipeline:
- **Archiver service** orchestrates the complete archival pipeline (fetch → classify → process → store)
- **ArchiveContentJob** provides job infrastructure with retry logic and calls the Archiver
- State machine transitions track progress through the pipeline
- Exponential backoff retry for network timeouts
- Link model integration triggers archival on creation

**Key components created:**
- `LinkRadar::ContentArchiving::Archiver` - Orchestrates the full archival pipeline with state management
- `ArchiveContentJob` - Background job infrastructure that calls the Archiver
- Link after_create callback - Triggers archive creation and job enqueue
- Sample data for testing the complete pipeline

**Architectural Design:**
- **Separation of Concerns**: Job handles ActiveJob infrastructure (retry, queuing), Archiver handles business logic
- **Clear Boundaries**: Job doesn't know about content types, HTML, or extraction - it just calls the Archiver
- **Testability**: Archiver can be tested independently without ActiveJob complexity
- **Simplicity**: Job is ~50 lines, Archiver contains all pipeline logic (~180 lines)

**Workflow**: Link created → ContentArchive created (pending) → Job enqueued → Job calls Archiver → Archiver fetches/classifies/processes → State transitions → Content stored (completed/failed)

**References:**
- Technical Spec: [spec.md](spec.md) sections 2.2 (Processing Flow), 5.2 (Background Job Integration)
- Requirements: [requirements.md](requirements.md) sections 2.1 (Automatic Content Archival), 2.4 (Failure Handling)

## Table of Contents

1. [Phase 6: Orchestration Service & Background Job](#1-phase-6-orchestration-service--background-job)
2. [Phase 7: Integration & Testing](#2-phase-7-integration--testing)

---

## 1. Phase 6: Orchestration Service & Background Job

**Implements:** spec.md#2.2 (Processing Flow), spec.md#5.2 (Background Job Integration), requirements.md#2.4 (Retry Logic)

Creates the Archiver service that orchestrates the content archival pipeline and the background job that provides retry infrastructure.

### 1.1 Create Archiver Service

**Create `backend/lib/link_radar/content_archiving/archiver.rb`** - the orchestration service:

- [ ] Create service file

```ruby
# frozen_string_literal: true

module LinkRadar
  module ContentArchiving
    # Orchestrates the complete content archival pipeline
    #
    # This service coordinates the full archival workflow:
    # 1. Transitions to processing state
    # 2. Fetches content via HttpFetcher (validates URL internally)
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
    # The background job (ArchiveContentJob) only handles ActiveJob infrastructure:
    # - Retry logic for timeouts
    # - Job queuing and execution
    # - Calling this Archiver service
    #
    # This separation keeps concerns clean:
    # - Job = infrastructure (retries, queuing, job-level error handling)
    # - Archiver = business logic (fetch, classify, process, store, state management)
    #
    # @example Success case
    #   archiver = Archiver.new(link: link, archive: archive)
    #   result = archiver.call
    #   result.success? # => true
    #   archive.current_state # => "completed"
    #
    # @example Failure case
    #   archiver = Archiver.new(link: link, archive: archive)
    #   result = archiver.call
    #   result.failure? # => true
    #   result.errors # => ["URL resolves to private IP..."]
    #   archive.current_state # => "failed"
    #
    class Archiver
      include LinkRadar::Resultable

      # @param link [Link] the link to archive
      # @param archive [ContentArchive] the archive record to populate
      # @param config [ContentArchiveConfig] optional config (defaults to new instance)
      def initialize(link:, archive:, config: nil)
        @link = link
        @archive = archive
        @config = config || ContentArchiveConfig.new
      end

      # Executes the archival pipeline
      #
      # @return [LinkRadar::Result] success or failure with error details
      def call
        # Check if archival is globally enabled
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
        fetch_result = HttpFetcher.new(link.url).call

        # Step 2: Handle fetch failure
        if fetch_result.failure?
          handle_fetch_failure(fetch_result)
          return fetch_result
        end

        # Step 3 & 4: Classify and process content
        if html_content?(fetch_result.data[:content_type])
          process_html_content(fetch_result)
        else
          process_binary_content(fetch_result)
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
      # @param fetch_result [LinkRadar::Result] the successful fetch result
      # @return [LinkRadar::Result] success or failure
      def process_html_content(fetch_result)
        # Extract content and metadata (returns ParsedContent value object)
        # NOTE: ContentExtractor automatically sanitizes HTML output for XSS protection
        extraction_result = ContentExtractor.new(
          html: fetch_result.data[:body],
          url: fetch_result.data[:final_url]
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
      # @param fetch_result [LinkRadar::Result] the successful fetch result
      # @return [LinkRadar::Result] success
      def process_binary_content(fetch_result)
        content_type = fetch_result.data[:content_type]
        final_url = fetch_result.data[:final_url]

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
```

### 1.2 Create ArchiveContentJob

**Create `backend/app/jobs/archive_content_job.rb`** - simplified job that calls the Archiver:

- [ ] Create job file

```ruby
# frozen_string_literal: true

# Background job to archive web page content for a Link
#
# This job provides ActiveJob infrastructure for the archival pipeline:
# - Retry logic for network timeouts (exponential backoff)
# - Job queuing and execution
# - Calls LinkRadar::ContentArchiving::Archiver to perform the actual work
#
# Architecture:
# - This job handles ONLY ActiveJob concerns (retry, queuing, job-level errors)
# - The Archiver service handles ALL business logic (fetch, classify, process, store)
#
# This separation keeps the job simple and focused on infrastructure,
# while the Archiver contains all the archival logic and can be tested
# independently without ActiveJob complexity.
#
# State Machine Integration:
# - Archiver transitions archive through states: pending → processing → completed/failed
# - completed with content_type in archive metadata (html, pdf, image, etc.)
# - failed with error_reason in transition metadata (blocked, invalid_url, network_error, etc.)
# - Transition history provides complete audit trail
#
# Retry Strategy (spec.md#5.2):
# - Network timeouts: Retry with exponential backoff (immediate, +2s, +4s)
# - Maximum 3 attempts total
# - Non-retryable errors (404, 5xx, validation failures): Fail immediately (no retry)
#
# @example Enqueue job
#   ArchiveContentJob.perform_later(link_id: link.id)
#
class ArchiveContentJob < ApplicationJob
  queue_as :default

  # Retry on network timeout errors only
  # Exponential backoff: wait = (2^attempts) * 2 seconds
  # Attempt 1: immediate
  # Attempt 2: 2 seconds
  # Attempt 3: 4 seconds
  retry_on Faraday::TimeoutError,
    wait: ->(executions) { 2**executions * 2 },
    attempts: 3

  # Discard on non-retryable errors (don't retry these)
  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  # @param link_id [String] UUID of the Link to archive
  # @param retry_count [Integer] current retry attempt (for tracking)
  def perform(link_id:, retry_count: 0)
    @link = Link.find(link_id)
    @archive = @link.content_archive
    @retry_count = retry_count

    # Track overall execution time
    start_time = Time.current

    # Call the Archiver service to perform the actual work
    archiver = LinkRadar::ContentArchiving::Archiver.new(
      link: @link,
      archive: @archive
    )
    result = archiver.call

    # Log completion if successful
    if result.success? && @archive.current_state == "completed"
      duration_ms = ((Time.current - start_time) * 1000).to_i
      Rails.logger.info "ContentArchive #{@archive.id} completed in #{duration_ms}ms"
    end
  rescue Faraday::TimeoutError => e
    # Handle timeout for retry tracking, then re-raise for ActiveJob retry
    handle_timeout_error(e)
    raise
  rescue => e
    # Unexpected job-level errors (shouldn't happen as Archiver handles its errors)
    handle_unexpected_job_error(e)
  end

  private

  # Handles timeout errors for retry tracking
  #
  # Logs the timeout and updates the archive state if this is the last attempt.
  # Then re-raises the error so ActiveJob retry logic can handle it.
  #
  # @param error [Faraday::TimeoutError] the timeout error
  # @return [void]
  def handle_timeout_error(error)
    current_attempt = executions

    Rails.logger.warn "ContentArchive #{@archive.id} timeout (attempt #{current_attempt}): #{error.message}"

    # If this is the last attempt, transition to failed
    # (ActiveJob won't retry again after this)
    if current_attempt >= 3
      ActiveRecord::Base.transaction do
      @archive.transition_to!(
        :failed,
        error_reason: "network_error",
          error_message: "Connection timeout after #{current_attempt} attempts",
          retry_count: current_attempt
      )
        @archive.update!(error_message: "Connection timeout after #{current_attempt} attempts")
      end
    end
  end

  # Handles unexpected job-level errors
  #
  # This should rarely happen since the Archiver handles its own errors.
  # This is a safety net for truly unexpected job infrastructure errors.
  #
  # @param error [StandardError] the unexpected error
  # @return [void]
  def handle_unexpected_job_error(error)
    error_message = "Unexpected job error: #{error.class} - #{error.message}"

    Rails.logger.error "ArchiveContentJob error for ContentArchive #{@archive.id}: #{error_message}"
    Rails.logger.error error.backtrace.join("\n")

    # Try to update archive state, but don't fail if archive is already in a bad state
    begin
      ActiveRecord::Base.transaction do
    @archive.transition_to!(
      :failed,
      error_reason: "unexpected_error",
      error_message: error_message,
      retry_count: executions
    )
        @archive.update!(error_message: error_message)
      end
    rescue => e
      # Last resort logging if even state transition fails
      Rails.logger.error "Failed to update archive state: #{e.message}"
    end
  end
end
```

### 1.3 Spec Structure

**Create `backend/spec/lib/link_radar/content_archiving/archiver_spec.rb`:**

```
describe LinkRadar::ContentArchiving::Archiver
  describe "#call"
    context "with HTML content archival"
      it "transitions from pending to processing to completed"
      it "fetches HTML content from URL via HttpFetcher"
      it "extracts and sanitizes content using ContentExtractor"
      it "stores content_html in archive (already sanitized)"
      it "stores content_text in archive"
      it "stores title in archive"
      it "stores description in archive"
      it "stores image_url in archive"
      it "stores content_type='html' in metadata"
      it "stores final_url in metadata"
      it "returns success result"
    
    context "with non-HTML content"
      it "transitions from pending to processing to completed"
      it "fetches content successfully via HttpFetcher"
      it "stores content_type='pdf' in metadata for PDFs"
      it "stores content_type='image' in metadata for images"
      it "stores content_type='video' in metadata for videos"
      it "stores content_type='other' in metadata for unknown types"
      it "stores mime_type in metadata"
      it "stores final_url in metadata"
      it "does not attempt content extraction"
      it "does not store content_html or content_text"
      it "returns success result"
    
    context "with invalid URL scheme"
      it "transitions to failed state with error_reason='invalid_url'"
      it "stores error message in archive"
      it "stores error_reason in transition metadata"
      it "does not attempt to fetch content"
      it "returns failure result"
    
    context "with private IP addresses (SSRF protection)"
      it "transitions to failed state with error_reason='blocked' for localhost"
      it "transitions to failed state with error_reason='blocked' for 192.168.x.x"
      it "transitions to failed state with error_reason='blocked' for 10.x.x.x"
      it "transitions to failed state with error_reason='blocked' for 127.0.0.1"
      it "stores error message about SSRF protection"
      it "stores error_reason='blocked' in transition metadata"
      it "returns failure result with error details"
    
    context "with HTTP fetch failures"
      it "transitions to failed state with error_reason='network_error' for 404"
      it "transitions to failed state with error_reason='network_error' for 500"
      it "transitions to failed state with error_reason='network_error' for connection failures"
      it "stores appropriate error message for each failure type"
      it "stores error_reason in transition metadata"
      it "stores http_status when applicable"
      it "returns failure result"
    
    context "with content size limits"
      it "transitions to failed state with error_reason='size_limit'"
      it "stores error message about size limit"
      it "stores error_reason='size_limit' in transition metadata"
      it "returns failure result"
    
    context "with redirect handling"
      it "follows redirects and archives final content"
      it "validates each redirect target via HttpFetcher"
      it "blocks redirect chains to private IPs with error_reason='blocked'"
      it "stores final URL in metadata for successful cases"
    
    context "with content extraction failures"
      it "transitions to failed state with error_reason='extraction_error'"
      it "stores error message from ContentExtractor"
      it "stores error_reason in transition metadata"
      it "returns failure result"
    
    context "with archival disabled"
      it "transitions to failed state with error_reason='disabled'"
      it "does not attempt to fetch content"
      it "returns failure result"
    
    context "with unexpected errors"
      it "transitions to failed state with error_reason='unexpected_error'"
      it "logs error with backtrace"
      it "stores error message in archive"
      it "returns failure result"
```

**Create `backend/spec/jobs/archive_content_job_spec.rb`:**

```
describe ArchiveContentJob
  describe "#perform"
    context "with successful archival"
      it "calls Archiver service with correct parameters"
      it "logs completion with duration"
      it "does not raise errors"
    
    context "with Archiver failure"
      it "does not raise errors (Archiver handles its own failures)"
      it "archive is left in failed state by Archiver"
    
    context "with timeout errors (retryable)"
      it "logs timeout on first attempt"
      it "re-raises error for ActiveJob retry"
      it "transitions to failed on final attempt (3rd)"
      it "stores retry_count in transition metadata"
    
    context "with missing Link"
      it "raises ActiveJob::DeserializationError"
      it "is discarded (not retried)"
    
    context "with missing ContentArchive"
      it "handles gracefully"
      it "logs error"
    
    context "with unexpected job-level errors"
      it "logs error with backtrace"
      it "attempts to update archive state"
      it "does not raise error (fail gracefully)"
```

---

## 2. Phase 7: Integration & Testing

**Implements:** spec.md#5.1 (Link Model Integration), requirements.md#2.1 (Automatic Content Archival)

Integrates archival with Link creation and performs end-to-end testing of the complete pipeline.

### 2.1 Add Link Creation Callback

**Edit `app/models/link.rb`** to add after_create callback:

- [ ] Add the callback registration (add to existing callbacks section):

```ruby
  # Callbacks
after_create :create_content_archive_and_enqueue_job
```

- [ ] Add the callback method (add to private methods section):

```ruby
  private

  # Creates ContentArchive and enqueues background archival job
  #
  # This callback is triggered after a Link is created. It:
  # 1. Creates a ContentArchive record (initial state: pending)
  # 2. Enqueues ArchiveContentJob to process content asynchronously
  #
  # Archival failures never block link creation - archive record is always
# created, and job failures are handled gracefully by the Archiver service.
  #
  # @return [void]
  def create_content_archive_and_enqueue_job
    # Create archive record (initial state: pending via state machine)
    archive = ContentArchive.create!(link: self)

    # Enqueue background job to fetch and archive content
    ArchiveContentJob.perform_later(link_id: id)

    Rails.logger.info "ContentArchive #{archive.id} created and job enqueued for Link #{id}"
  rescue => e
    # If archive creation fails, log error but don't fail link creation
    Rails.logger.error "Failed to create ContentArchive for Link #{id}: #{e.message}"
  end
```

---

## Completion Checklist

Orchestration and integration complete when:
- [ ] Archiver service successfully orchestrates the full pipeline
- [ ] Archiver handles HTML content (full extraction) and non-HTML content (metadata only)
- [ ] Archiver handles all failure scenarios with appropriate error_reason values
- [ ] Archiver manages all state machine transitions
- [ ] ArchiveContentJob successfully calls Archiver service
- [ ] Job retry logic works for timeout errors (exponential backoff)
- [ ] Link creation automatically creates archive and enqueues job
- [ ] State machine uses 4 states: pending, processing, completed, failed
- [ ] Archive metadata includes content_type for completed archives
- [ ] Transition metadata includes error_reason for failed archives
- [ ] RSpec tests implemented for Archiver service following spec structure
- [ ] RSpec tests implemented for ArchiveContentJob following spec structure
- [ ] All specs passing with coverage of HTML, non-HTML, and failure scenarios
- [ ] Manual testing passes for all test cases
- [ ] Cascade delete works (link deletion removes archive and transitions)
- [ ] Sample data created and verified
- [ ] Configuration requirements documented

**Implementation Complete!** Content archival system is fully functional with clean separation between job infrastructure and business logic.

**Architecture Benefits:**
- Job is simple and focused on ActiveJob concerns (~50 lines)
- Archiver contains all business logic and is independently testable (~180 lines)
- Clear separation of concerns (infrastructure vs. business logic)
- Easy to test each component in isolation
- Easy to understand and maintain

**Future Work:** See [future.md](future.md) for Phase 2+ enhancements (JavaScript rendering, local image storage, re-fetch capability).
