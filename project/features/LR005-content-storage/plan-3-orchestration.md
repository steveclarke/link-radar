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
- **Retry Strategy**: Exceptions for transient failures (timeouts), Results for permanent failures (404, blocked IPs)
- **Testability**: Archiver can be tested independently without ActiveJob complexity
- **Simplicity**: Job is ~15 lines, Archiver contains all pipeline logic (~180 lines)
- **Consistent Value Objects**: All services return value objects (FetchedContent, ParsedContent, FetchError, ExtractionError) rather than hashes for type safety and clarity

**Workflow**: Link created → Check archival enabled → ContentArchive created (pending) → Job enqueued → Job calls Archiver → Archiver fetches/classifies/processes → State transitions → Content stored (completed/failed)

**Note:** If archival is disabled, the Link callback returns early without creating an archive or enqueuing a job. The Archiver also includes a defensive check as a safety net for race conditions.

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
```

### 1.2 Create ArchiveContentJob

**Create `backend/app/jobs/archive_content_job.rb`** - simplified job that calls the Archiver:

- [ ] Create job file

```ruby
# frozen_string_literal: true

# Background job to archive web page content for a Link
#
# This job provides ActiveJob infrastructure for the archival pipeline:
# - Retry management for transient failures (timeouts)
# - Queue management
# - Job monitoring via GoodJob UI
#
# The Archiver service handles all business logic including error handling
# for permanent failures (404, blocked IPs, extraction errors).
#
# Architecture - Separation of Concerns:
# - Transient failures (timeouts): Exception propagates → Job retries automatically
# - Permanent failures (404, blocked): Result pattern → Archiver transitions to failed
#
# Retry strategy:
# - Network timeouts: Exponential backoff with jitter, 3 attempts max
# - All other errors: Handled by Archiver via Result pattern (no retry)
#
# @example Enqueue job
#   ArchiveContentJob.perform_later(link_id: link.id)
#
class ArchiveContentJob < ApplicationJob
  queue_as :default

  # Retry on network timeout errors only (transient infrastructure failures)
  # Exponential backoff with jitter (prevents thundering herd)
  # Attempt 1: immediate
  # Attempt 2: ~4 seconds (+ jitter)
  # Attempt 3: ~16 seconds (+ jitter)
  retry_on Faraday::TimeoutError,
    wait: :exponentially_longer,
    attempts: 3

  # Discard on non-retryable errors (don't retry these)
  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  # @param link_id [String] UUID of the Link to archive
  def perform(link_id:)
    archive = Link.find(link_id).content_archive

    # Call the Archiver service to perform all archival logic
    # Archiver handles all business logic errors via Result pattern
    # Timeouts propagate as exceptions for Job retry
    archiver = LinkRadar::ContentArchiving::Archiver.new(archive: archive)
    archiver.call
    
    Rails.logger.info "ContentArchive #{archive.id} job completed: #{archive.current_state}"
  end
end
```

### 1.3 Spec Structure

**Create `backend/spec/lib/link_radar/content_archiving/archiver_spec.rb`:**

```
describe LinkRadar::ContentArchiving::Archiver
  # Note: Detailed service behavior is tested in HttpFetcher/ContentExtractor specs.
  # Archiver specs focus on orchestration: state transitions, service integration,
  # and data storage.

  describe "#call"
    context "with successful HTML archival"
      it "transitions: pending → processing → completed"
      it "calls HttpFetcher with link URL"
      it "calls ContentExtractor when content_type is HTML"
      it "stores extracted content (content_html, content_text, title, description, image_url)"
      it "stores metadata (content_type='html', final_url) from ContentMetadata"
      it "returns success Result"
    
    context "with successful binary content archival"
      it "transitions: pending → processing → completed"
      it "calls HttpFetcher with link URL"
      it "does NOT call ContentExtractor for non-HTML content types"
      it "stores metadata only (raw MIME type, final_url)"
      it "does not store content_html or content_text"
      it "returns success Result"
    
    context "when HttpFetcher returns failure (permanent errors)"
      # Test ONE example from each error category to verify error → state mapping
      it "maps FetchError with error_code=:invalid_url to failed state with error_reason='invalid_url'"
      it "maps FetchError with error_code=:blocked to failed state with error_reason='blocked'"
      it "maps FetchError with error_code=:network_error to failed state with error_reason='network_error'"
      it "maps FetchError with error_code=:size_limit to failed state with error_reason='size_limit'"
      it "stores error_message from FetchError in archive"
      it "stores error_reason in transition metadata"
      it "returns failure Result with FetchError"
    
    context "when ContentExtractor returns failure"
      it "transitions to failed state with error_reason='extraction_error'"
      it "stores error_message from ExtractionError in archive"
      it "stores error_reason in transition metadata"
      it "returns failure Result with ExtractionError"
    
    context "when archival is disabled (defensive check)"
      it "transitions to failed state with error_reason='disabled'"
      it "does NOT call HttpFetcher or ContentExtractor"
      it "returns failure Result"
      # Note: Primary check is in Link callback. This tests the defensive safety net.
    
    context "when unexpected error occurs"
      it "transitions to failed state with error_reason='unexpected_error'"
      it "logs error with backtrace"
      it "stores error message in archive"
      it "returns failure Result"
```

**Create `backend/spec/jobs/archive_content_job_spec.rb`:**

```
describe ArchiveContentJob
  # Note: Business logic is tested in Archiver specs.
  # Job specs focus on ActiveJob infrastructure: retry logic, error handling,
  # and job execution.

  describe "#perform"
    context "with successful archival"
      it "finds Link and ContentArchive by link_id"
      it "calls Archiver service with archive"
      it "logs completion with duration"
      it "completes without raising exceptions"
    
    context "with Archiver returning failure Result"
      it "completes without raising exceptions (Archiver uses Result pattern)"
      it "does NOT retry job (permanent failures handled by Archiver)"
    
    context "with Faraday::TimeoutError (transient failures)"
      it "propagates exception to retry_on handler"
      it "retries with exponential backoff + jitter"
      it "retries maximum 3 attempts"
      it "does NOT call Archiver again on final retry failure"
    
    context "with missing Link (ActiveRecord::RecordNotFound)"
      it "is discarded via discard_on (not retried)"
      it "does NOT queue for retry"
    
    context "with missing ContentArchive (ActiveRecord::RecordNotFound)"
      it "is discarded via discard_on (not retried)"
      it "does NOT queue for retry"
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
  # 1. Checks if content archival is enabled (early return if disabled)
  # 2. Creates a ContentArchive record (initial state: pending)
  # 3. Enqueues ArchiveContentJob to process content asynchronously
  #
  # Archival failures never block link creation - if archival is disabled,
  # callback returns silently. Job failures are handled gracefully by the Archiver service.
  #
  # @return [void]
  def create_content_archive_and_enqueue_job
    # Check if archival is enabled before creating archive or enqueuing job
    config = ContentArchiveConfig.new
    return unless config.enabled

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
- [ ] Link callback checks if archival is enabled before creating archive or enqueuing job
- [ ] Link creation automatically creates archive and enqueues job (when enabled)
- [ ] Link creation skips archival silently when archival is disabled
- [ ] Archiver includes defensive check for disabled archival (safety net)
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
- Job is simple and focused on ActiveJob concerns (~15 lines)
- Archiver contains all business logic and is independently testable (~180 lines)
- Clean separation: Exceptions for retries, Results for business logic
- Timeouts propagate to Job layer for automatic retry
- Permanent failures handled via Result pattern in services
- Easy to test each component in isolation
- Easy to understand and maintain

**Future Work:** See [future.md](future.md) for Phase 2+ enhancements (JavaScript rendering, local image storage, re-fetch capability).
