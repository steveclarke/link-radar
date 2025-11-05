# LR005 - Content Archival & Storage: Orchestration Plan

## Overview

This plan implements the background job that orchestrates the content archival pipeline and integrates it with Link creation:
- ArchiveContentJob coordinates service calls with retry logic
- State machine transitions track progress through the pipeline
- Exponential backoff retry for network timeouts
- Link model integration triggers archival on creation

**Key components created:**
- ArchiveContentJob - Background job orchestrating the archival pipeline
- Link after_create callback - Triggers archive creation and job enqueue
- Sample data for testing the complete pipeline

**Workflow**: Link created → ContentArchive created (pending) → Job enqueued → Services called → State transitions → Content stored (success/failed/blocked)

**References:**
- Technical Spec: [spec.md](spec.md) sections 2.2 (Processing Flow), 5.2 (Background Job Integration)
- Requirements: [requirements.md](requirements.md) sections 2.1 (Automatic Content Archival), 2.4 (Failure Handling)

## Table of Contents

1. [Phase 6: Background Job](#1-phase-6-background-job)
2. [Phase 7: Integration & Testing](#2-phase-7-integration--testing)

---

## 1. Phase 6: Background Job

**Implements:** spec.md#2.2 (Processing Flow), spec.md#5.2 (Background Job Integration), requirements.md#2.4 (Retry Logic)

Creates background job that orchestrates the content archival pipeline with retry logic and state machine integration.

### 1.1 Create ArchiveContentJob

**Create `backend/app/jobs/archive_content_job.rb`** with full retry logic:

- [ ] Create job file

```ruby
# frozen_string_literal: true

# Background job to archive web page content for a Link
#
# This job orchestrates the content archival pipeline:
# 1. Fetches content via HTTP (HttpFetcher validates URL internally)
# 2. Checks content type (HTML vs PDF/image/etc)
# 3. For HTML: Extracts content/metadata and sanitizes
# 4. For non-HTML: Stores metadata only
# 5. Stores results in ContentArchive
#
# State Machine Integration:
# - Job transitions archive through states: pending → processing → completed/failed
# - completed with content_type in archive metadata (html, pdf, image, etc.)
# - failed with error_reason in transition metadata (blocked, invalid_url, network_error, etc.)
# - Transition history provides complete audit trail
#
# Retry Strategy (spec.md#5.2):
# - Network timeouts: Retry with exponential backoff (immediate, +2s, +4s)
# - Maximum 3 attempts total
# - Non-retryable errors (404, 5xx, validation failures): Fail immediately
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
  def perform(link_id:)
    @link = Link.find(link_id)
    @archive = @link.content_archive
    @config = ContentArchiveConfig.new

    # Check if archival is globally enabled
    unless @config.enabled
      @archive.transition_to!(:failed, error_message: "Content archival disabled")
      return
    end

    # Track overall execution time
    start_time = Time.current

    # Execute archival pipeline
    execute_pipeline

    # Record successful completion duration
    if @archive.current_state == "completed"
      duration_ms = ((Time.current - start_time) * 1000).to_i
      Rails.logger.info "ContentArchive #{@archive.id} completed in #{duration_ms}ms"
    end
  rescue Faraday::TimeoutError => e
    # Let ActiveJob retry handle this (will re-raise)
    handle_timeout_error(e)
    raise
  rescue => e
    # Unexpected errors - fail immediately without retry
    handle_unexpected_error(e)
  end

  private

  # Executes the archival pipeline step by step
  #
  # Pipeline steps:
  # 1. Transition to processing
  # 2. Fetch content (HttpFetcher validates URL internally)
  # 3. Check content type
  # 4a. If HTML: Extract, sanitize, store with content_type="html"
  # 4b. If non-HTML: Store metadata with content_type="pdf"/"image"/etc
  # 5. Transition to completed
  #
  # Note: URL validation is handled internally by HttpFetcher (security boundary).
  # HttpFetcher validates both the initial URL and all redirect targets.
  #
  # @return [void]
  def execute_pipeline
    # Step 1: Begin processing
    @archive.transition_to!(:processing)

    # Step 2: Fetch content
    # HttpFetcher validates URL internally (initial URL + all redirects)
    fetch_result = LinkRadar::ContentArchiving::HttpFetcher.new(@link.url).call
    if fetch_result.failure?
      return handle_fetch_failure(fetch_result)
    end

    # Step 3: Check content type
    if html_content_type?(fetch_result.data[:content_type])
      # Step 4a: HTML pipeline
      handle_html_content(fetch_result)
    else
      # Step 4b: Non-HTML pipeline
      handle_non_html_content(fetch_result)
    end
  end

  # Handles HTTP fetch failures (includes validation failures from HttpFetcher)
  #
  # HttpFetcher validates URLs internally, so this handler receives both:
  # 1. Validation failures (invalid URL, private IP, DNS errors)
  # 2. Fetch failures (404, 5xx, timeouts, size limits)
  #
  # All failures transition to :failed state with appropriate error_reason.
  #
  # @param result [LinkRadar::Result] the failed fetch result
  # @return [void]
  def handle_fetch_failure(result)
    error_message = result.errors.first
    metadata = result.data || {}

    # Determine error reason based on error type
    error_reason = if error_message.include?("private IP") || metadata[:validation_reason] == "private_ip"
      "blocked"
    elsif error_message.include?("scheme must be") || 
          error_message.include?("Invalid URL") ||
          error_message.include?("Malformed URL") ||
          error_message.include?("DNS resolution failed")
      "invalid_url"
    elsif error_message.include?("Content size exceeds") || error_message.include?("size limit")
      "size_limit"
    elsif error_message.include?("timeout") || error_message.include?("Timeout")
      "network_error"
    elsif metadata[:http_status]
      "network_error"
    else
      "network_error"
    end

    # Transition to failed with error reason
    @archive.transition_to!(
      :failed,
      error_reason: error_reason,
      error_message: error_message,
      http_status: metadata[:http_status],
      retry_count: executions
    )

    @archive.update(error_message: error_message)
  end

  # Handles content extraction failures
  #
  # @param result [LinkRadar::Result] the failed extraction result
  # @return [void]
  def handle_extraction_failure(result)
    error_message = result.errors.first

    @archive.transition_to!(
      :failed,
      error_reason: "extraction_error",
      error_message: error_message,
      retry_count: executions
    )

    @archive.update(error_message: error_message)
  end

  # Handles timeout errors (for retry logging)
  #
  # @param error [Faraday::TimeoutError] the timeout error
  # @return [void]
  def handle_timeout_error(error)
    Rails.logger.warn "ContentArchive #{@archive.id} timeout (attempt #{executions}): #{error.message}"

    # If this is the last attempt, transition to failed
    if executions >= 3
      @archive.transition_to!(
        :failed,
        error_reason: "network_error",
        error_message: "Connection timeout after #{executions} attempts",
        retry_count: executions
      )
      @archive.update(error_message: "Connection timeout after #{executions} attempts")
    end
  end

  # Handles unexpected errors
  #
  # @param error [StandardError] the unexpected error
  # @return [void]
  def handle_unexpected_error(error)
    error_message = "Unexpected error: #{error.class} - #{error.message}"

    Rails.logger.error "ContentArchive #{@archive.id} error: #{error_message}"
    Rails.logger.error error.backtrace.join("\n")

    @archive.transition_to!(
      :failed,
      error_reason: "unexpected_error",
      error_message: error_message,
      retry_count: executions
    )

    @archive.update(error_message: error_message)
  end

  # Checks if content type is HTML
  #
  # Phase 1 supports only HTML content for full extraction.
  # Other content types (PDF, images, etc.) are stored with metadata only.
  #
  # @param content_type [String] the Content-Type header value
  # @return [Boolean] true if HTML, false otherwise
  def html_content_type?(content_type)
    return false if content_type.blank?
    
    content_type.downcase.include?("text/html") || 
      content_type.downcase.include?("application/xhtml+xml")
  end

  # Handles HTML content - full extraction pipeline
  #
  # @param fetch_result [LinkRadar::Result] the successful fetch result
  # @return [void]
  def handle_html_content(fetch_result)
    # Extract content and metadata (returns ParsedContent value object)
    # NOTE: ContentExtractor automatically sanitizes HTML output for XSS protection
    extraction_result = LinkRadar::ContentArchiving::ContentExtractor.new(
      html: fetch_result.data[:body],
      url: fetch_result.data[:final_url]
    ).call
    return handle_extraction_failure(extraction_result) if extraction_result.failure?

    parsed = extraction_result.data # ParsedContent instance (content_html is already sanitized)

    # Store results with content_type: "html"
    @archive.update!(
      content_html: parsed.content_html, # Already XSS-safe from ContentExtractor
      content_text: parsed.content_text,
      title: parsed.title,
      description: parsed.description,
      image_url: parsed.image_url,
      metadata: build_metadata_hash(parsed.metadata, fetch_result),
      fetched_at: Time.current
    )

    # Transition to completed
    @archive.transition_to!(:completed)
    Rails.logger.info "ContentArchive #{@archive.id} completed (HTML)"
  end

  # Handles non-HTML content (PDFs, images, etc.)
  #
  # Phase 1: Store basic metadata only (URL + content type)
  # Future: Add PDF text extraction, image processing, etc.
  #
  # @param fetch_result [LinkRadar::Result] the successful fetch result
  # @return [void]
  def handle_non_html_content(fetch_result)
    content_type = fetch_result.data[:content_type]
    final_url = fetch_result.data[:final_url]
    
    # Determine simplified content type category
    type_category = case content_type
    when /pdf/ then "pdf"
    when /image/ then "image"
    when /video/ then "video"
    else "other"
    end
    
    # Store basic information about the non-HTML content
    @archive.update(
      metadata: {
        content_type: type_category,
        mime_type: content_type,
        final_url: final_url
      },
      fetched_at: Time.current
    )

    # Transition to completed
    @archive.transition_to!(:completed)
    Rails.logger.info "ContentArchive #{@archive.id} completed (#{type_category})"
  end

  # Builds metadata hash from ContentMetadata value object
  #
  # @param content_metadata [ContentMetadata] the metadata value object
  # @param fetch_result [LinkRadar::Result] the fetch result with final_url
  # @return [Hash] metadata hash for storage
  def build_metadata_hash(content_metadata, fetch_result)
    {
      opengraph: content_metadata.opengraph,
      twitter: content_metadata.twitter,
      canonical_url: content_metadata.canonical_url,
      content_type: "html",
      final_url: fetch_result.data[:final_url]
    }.compact
  end
end
```

### 1.2 Verification

**Test ArchiveContentJob in Rails console:**

- [ ] Create test link: `link = Link.create!(url: "https://example.com", submitted_url: "https://example.com")`
- [ ] Create archive: `archive = ContentArchive.create!(link: link)`
- [ ] Enqueue job: `ArchiveContentJob.perform_now(link_id: link.id)`
- [ ] Check state: `archive.reload.current_state`
- [ ] Check content: `archive.content_html`, `archive.content_text`, `archive.title`
- [ ] Check metadata: `archive.metadata`
- [ ] Check transitions: `archive.content_archive_transitions.order(created_at: :asc).pluck(:to_state, :created_at)`

**Test failure cases:**

- [ ] Test invalid URL: Create link with `url: "ftp://example.com"`, run job, verify `failed` state with `error_reason: "invalid_url"`
- [ ] Test private IP: Create link with `url: "http://192.168.1.1"`, run job, verify `failed` state with `error_reason: "blocked"`
- [ ] Test 404: Create link with `url: "https://example.com/nonexistent"`, run job, verify `failed` state with `error_reason: "network_error"`

**Test non-HTML content:**

- [ ] Test PDF: Create link to PDF URL, run job, verify `completed` state with `metadata["content_type"]: "pdf"`

### 1.3 Spec Structure

**Create `backend/spec/jobs/archive_content_job_spec.rb`:**

```
describe ArchiveContentJob
  describe "#perform"
    context "with HTML content archival"
      it "transitions from pending to processing to completed"
      it "fetches HTML content from URL"
      it "extracts and sanitizes content using ContentExtractor (XSS-safe output)"
      it "stores content_html in archive (already sanitized)"
      it "stores content_text in archive"
      it "stores title in archive"
      it "stores description in archive"
      it "stores image_url in archive"
      it "stores content_type='html' in metadata"
      it "stores final_url in metadata"
      it "records all state transitions"
      it "includes transition metadata for each state"
    
    context "with non-HTML content"
      it "transitions from pending to processing to completed"
      it "fetches content successfully"
      it "stores content_type='pdf' in metadata for PDFs"
      it "stores content_type='image' in metadata for images"
      it "stores content_type='video' in metadata for videos"
      it "stores content_type='other' in metadata for unknown types"
      it "stores mime_type in metadata"
      it "stores final_url in metadata"
      it "does not attempt content extraction"
      it "does not attempt HTML sanitization"
      it "does not store content_html or content_text"
    
    context "with invalid URL scheme"
      it "transitions to failed state with error_reason='invalid_url'"
      it "stores error message"
      it "stores error_reason in transition metadata"
      it "does not attempt to fetch content"
      it "records pending -> processing -> failed transitions"
    
    context "with private IP addresses (SSRF protection)"
      it "transitions to failed state with error_reason='blocked' for localhost"
      it "transitions to failed state with error_reason='blocked' for 192.168.x.x"
      it "transitions to failed state with error_reason='blocked' for 10.x.x.x"
      it "transitions to failed state with error_reason='blocked' for 127.0.0.1"
      it "stores error message about SSRF protection"
      it "stores error_reason='blocked' in transition metadata"
      it "records pending -> processing -> failed transitions"
    
    context "with HTTP fetch failures"
      it "transitions to failed state with error_reason='network_error' for 404"
      it "transitions to failed state with error_reason='network_error' for 500"
      it "transitions to failed state with error_reason='network_error' for timeouts"
      it "transitions to failed state with error_reason='network_error' for connection failures"
      it "stores appropriate error message for each failure type"
      it "stores error_reason in transition metadata"
      it "stores http_status when applicable"
      it "records pending -> processing -> failed transitions"
    
    context "with content size limits"
      it "transitions to failed state with error_reason='size_limit'"
      it "stores error message about size limit"
      it "stores error_reason='size_limit' in transition metadata"
    
    context "with redirect handling"
      it "follows redirects and archives final content"
      it "validates each redirect target"
      it "blocks redirect chains to private IPs with error_reason='blocked'"
      it "stores error when redirect validation fails"
      it "stores final URL in metadata for successful cases"
    
    context "with content extraction failures"
      it "transitions to failed state with error_reason='extraction_error'"
      it "stores error message from ContentExtractor"
      it "stores error_reason in transition metadata"
      it "handles sanitization errors within ContentExtractor as extraction errors"
    
    context "with missing ContentArchive"
      it "logs error when archive not found for link"
      it "does not raise exception"
      it "handles gracefully"
    
    context "with missing Link"
      it "logs error when link not found"
      it "does not raise exception"
      it "handles gracefully"
    
    context "with state machine transitions"
      it "correctly uses ContentArchiveTransition model"
      it "stores transition metadata for completed"
      it "stores error_reason for failures"
      it "maintains transition order by created_at"
    
    context "with service integration"
      it "calls HttpFetcher with correct URL"
      it "checks content type before processing"
      it "calls ContentExtractor for HTML content only (sanitization built-in)"
      it "does not call separate sanitization service (handled by ContentExtractor)"
      it "propagates errors from services correctly"
      it "maps service errors to appropriate error_reason values"
```

---

## 2. Phase 7: Integration & Testing

**Implements:** spec.md#5.1 (Link Model Integration), requirements.md#2.1 (Automatic Content Archival)

Integrates archival with Link creation and performs end-to-end testing of the complete pipeline.

### 2.1 Add Link Creation Callback

**Edit `app/models/link.rb`** to add after_create callback:

- [ ] Add callback to create archive and enqueue job

```ruby
class Link < ApplicationRecord
  # Associations
  has_many :link_tags, dependent: :destroy
  has_many :tags, through: :link_tags
  has_one :content_archive, dependent: :destroy

  # Virtual attribute for tag assignment
  attr_accessor :tag_names

  # Fetch state enum backed by Postgres enum type
  # (This can be removed once fully migrated to ContentArchive)
  # enum :fetch_state, {
  #   pending: "pending",
  #   success: "success",
  #   failed: "failed"
  # }, prefix: true

  # Validations
  validates :url, presence: true, length: {maximum: 2048}
  validates :submitted_url, presence: true, length: {maximum: 2048}
  validates :title, length: {maximum: 500}
  validates :image_url, length: {maximum: 2048}

  # Callbacks
  after_save :process_tag_names, if: -> { !@tag_names.nil? }
  after_create :create_content_archive_and_enqueue_job  # ADD THIS LINE

  private

  # Creates ContentArchive and enqueues background archival job
  #
  # This callback is triggered after a Link is created. It:
  # 1. Creates a ContentArchive record (initial state: pending)
  # 2. Enqueues ArchiveContentJob to process content asynchronously
  #
  # Archival failures never block link creation - archive record is always
  # created, and job failures are handled gracefully.
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

  # Callback orchestrator for processing tag names after save
  #
  # This method is triggered by the after_save callback when @tag_names is set.
  # It wraps the core tag assignment logic in a transaction and handles cleanup.
  #
  # @note This is a private callback method. For direct tag assignment, use {#assign_tags}.
  # @see #assign_tags for the core tag assignment logic
  # @return [void]
  def process_tag_names
    transaction do
      assign_tags(@tag_names)
    end
  ensure
    # Clear the virtual attribute after processing
    @tag_names = nil
  end

  # Core logic for assigning tags to a link
  #
  # Normalizes tag names, finds or creates Tag records, and replaces the link's
  # current tags with the new set. This method contains the business logic for
  # tag assignment and can be called directly or via the callback orchestrator.
  #
  # @param tag_names [Array<String>] array of tag names (empty array clears all tags)
  # @return [Array<Tag>] the assigned tags
  # @see #process_tag_names for the callback wrapper that invokes this method
  def assign_tags(tag_names)
    # Normalize tag names
    normalized_names = Array(tag_names).map(&:strip).compact_blank.uniq

    # Find or create tags
    new_tags = normalized_names.map do |name|
      Tag.find_or_create_by(name: name)
    end

    # Replace existing tags with new set (including empty array to clear all)
    self.tags = new_tags
  end
end
```

### 2.2 Create Sample Data for Testing

**Create sample data in Rails console for testing:**

- [ ] Open Rails console: `rails console`
- [ ] Clear existing test data: `Link.where(url: [test URLs]).destroy_all`
- [ ] Create sample links with archives:

```ruby
# Sample 1: News article (should succeed)
link1 = Link.create!(
  url: "https://example.com",
  submitted_url: "https://example.com",
  note: "Test article - should succeed"
)
# Archive and job automatically created by callback
puts "Created link #{link1.id} with archive #{link1.content_archive.id}"

# Sample 2: GitHub README (should succeed)
link2 = Link.create!(
  url: "https://github.com/rails/rails",
  submitted_url: "https://github.com/rails/rails",
  note: "Rails repository - should succeed"
)
puts "Created link #{link2.id} with archive #{link2.content_archive.id}"

# Sample 3: Private IP (should be blocked)
link3 = Link.create!(
  url: "http://192.168.1.1",
  submitted_url: "http://192.168.1.1",
  note: "Private IP - should be blocked"
)
puts "Created link #{link3.id} with archive #{link3.content_archive.id}"

# Sample 4: Invalid scheme (should be invalid_url)
link4 = Link.create!(
  url: "ftp://example.com",
  submitted_url: "ftp://example.com",
  note: "FTP URL - should be invalid_url"
)
puts "Created link #{link4.id} with archive #{link4.content_archive.id}"
```

### 2.3 Manual Testing - End-to-End Workflow

**Test the complete archival pipeline:**

- [ ] **Test 1: Successful HTML archival**
  - Create link: `link = Link.create!(url: "https://example.com", submitted_url: "https://example.com")`
  - Verify archive created: `link.content_archive.present?`
  - Verify initial state: `link.content_archive.current_state == "pending"`
  - Wait for job to complete (or run synchronously): `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify completed state: `link.content_archive.reload.current_state == "completed"`
  - Verify content stored: `link.content_archive.content_html.present?`
  - Verify content_type: `link.content_archive.metadata["content_type"] == "html"`
  - Verify transitions: `link.content_archive.content_archive_transitions.order(created_at: :asc).pluck(:to_state)`
    - Should show: `["pending", "processing", "completed"]`

- [ ] **Test 2: Private IP blocked**
  - Create link: `link = Link.create!(url: "http://192.168.1.1", submitted_url: "http://192.168.1.1")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify failed state: `link.content_archive.reload.current_state == "failed"`
  - Verify error_reason: Check last transition `metadata["error_reason"] == "blocked"`
  - Verify error message: `link.content_archive.error_message`
  - Verify transitions: `["pending", "processing", "failed"]`

- [ ] **Test 3: Invalid URL scheme**
  - Create link: `link = Link.create!(url: "ftp://example.com", submitted_url: "ftp://example.com")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify failed state: `link.content_archive.reload.current_state == "failed"`
  - Verify error_reason: Check last transition `metadata["error_reason"] == "invalid_url"`
  - Verify error message contains "scheme"
  - Verify transitions: `["pending", "processing", "failed"]`

- [ ] **Test 4: HTTP 404 error**
  - Create link: `link = Link.create!(url: "https://example.com/nonexistent", submitted_url: "https://example.com/nonexistent")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify failed state: `link.content_archive.reload.current_state == "failed"`
  - Verify error_reason: Check last transition `metadata["error_reason"] == "network_error"`
  - Verify error message contains "404"
  - Verify transitions: `["pending", "processing", "failed"]`

- [ ] **Test 5: Non-HTML content (PDF)**
  - Create link to PDF: `link = Link.create!(url: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf", submitted_url: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify completed state: `link.content_archive.reload.current_state == "completed"`
  - Verify content_type: `link.content_archive.metadata["content_type"] == "pdf"`
  - Verify metadata has mime_type: `link.content_archive.metadata["mime_type"]`
  - Verify metadata has final_url: `link.content_archive.metadata["final_url"]`
  - Verify no content extraction: `link.content_archive.content_html.nil?`
  - Verify transitions: `["pending", "processing", "completed"]`

- [ ] **Test 6: Cascade delete**
  - Create link with archive: `link = Link.create!(url: "https://example.com", submitted_url: "https://example.com")`
  - Note archive ID: `archive_id = link.content_archive.id`
  - Delete link: `link.destroy`
  - Verify archive deleted: `ContentArchive.find_by(id: archive_id).nil?`
  - Verify transitions deleted: `ContentArchiveTransition.where(content_archive_id: archive_id).count == 0`

- [ ] **Test 6: Background job processing**
  - Create link (job enqueued automatically): `link = Link.create!(url: "https://example.com", submitted_url: "https://example.com")`
  - Check GoodJob dashboard: Open `http://localhost:3000/good_job` (if enabled)
  - Verify job was enqueued
  - Wait for job to complete automatically
  - Refresh archive state: `link.content_archive.reload.current_state`

### 2.4 Testing Summary

**Document test results in Rails console:**

- [ ] Run test summary query:

```ruby
# Summary of all archives by state
ContentArchive
  .in_state(:completed, :failed, :pending, :processing)
  .group(:to_state)
  .count

# Recent archives with details
ContentArchive.includes(:link).order(created_at: :desc).limit(10).each do |archive|
  content_type = archive.metadata["content_type"] if archive.metadata.present?
  puts "Archive #{archive.id}: #{archive.current_state} (#{content_type}) - #{archive.link.url}"
  puts "  Error: #{archive.error_message}" if archive.error_message.present?
  puts "  Title: #{archive.title}" if archive.title.present?
  puts "  Fetched: #{archive.fetched_at}" if archive.fetched_at.present?
  puts "---"
end
```

### 2.5 Configuration Setup Instructions

**Document required configuration for deployment:**

- [ ] Create deployment configuration note in console:

```ruby
puts <<~CONFIG
  ========================================
  Content Archival Configuration Required
  ========================================
  
  Before deploying to production, set:
  
  Environment variable:
    CONTENT_ARCHIVE_USER_AGENT_CONTACT_URL=https://your-site.com
  
  Or in Rails credentials:
    rails credentials:edit
    
    content_archive:
      user_agent_contact_url: https://your-site.com
  
  This URL will be included in User-Agent headers when fetching
  web pages, allowing site owners to contact you if needed.
  
  Example User-Agent:
    LinkRadar/1.0 (+https://github.com/username/link-radar)
  ========================================
CONFIG
```

---

## Completion Checklist

Orchestration and integration complete when:
- [ ] ArchiveContentJob successfully orchestrates the full pipeline
- [ ] Job handles HTML content (full extraction) and non-HTML content (metadata only)
- [ ] Job handles all failure scenarios with appropriate error_reason values
- [ ] Retry logic works for timeout errors (exponential backoff)
- [ ] Link creation automatically creates archive and enqueues job
- [ ] State machine uses 4 states: pending, processing, completed, failed
- [ ] Archive metadata includes content_type for completed archives
- [ ] Transition metadata includes error_reason for failed archives
- [ ] RSpec tests implemented for ArchiveContentJob following spec structure
- [ ] All specs passing with coverage of HTML, non-HTML, and failure scenarios
- [ ] Manual testing passes for all test cases
- [ ] Cascade delete works (link deletion removes archive and transitions)
- [ ] Sample data created and verified
- [ ] Configuration requirements documented

**Implementation Complete!** Content archival system is fully functional and integrated with Link creation.

**Future Work:** See [future.md](future.md) for Phase 2+ enhancements (JavaScript rendering, local image storage, re-fetch capability).

