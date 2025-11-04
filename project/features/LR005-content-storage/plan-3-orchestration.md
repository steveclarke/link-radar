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
# 1. Validates URL (scheme, private IP detection)
# 2. Fetches HTML content via HTTP
# 3. Extracts content and metadata
# 4. Sanitizes HTML
# 5. Stores results in ContentArchive
#
# State Machine Integration:
# - Job transitions archive through states: pending → processing → success/failed
# - All transitions include metadata for debugging (error messages, duration, etc.)
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
    if @archive.current_state == "success"
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
  # 2. Validate URL
  # 3. Fetch HTML content
  # 4. Extract content and metadata
  # 5. Sanitize HTML
  # 6. Store results
  # 7. Transition to success
  #
  # @return [void]
  def execute_pipeline
    # Step 1: Begin processing
    @archive.transition_to!(:processing)

    # Step 2: Validate URL
    validation_result = LinkRadar::ContentArchiving::UrlValidator.new(@link.url).call
    if validation_result.failure?
      return handle_validation_failure(validation_result)
    end

    # Step 3: Fetch HTML content
    fetch_result = LinkRadar::ContentArchiving::HttpFetcher.new(@link.url).call
    if fetch_result.failure?
      return handle_fetch_failure(fetch_result)
    end

    # Step 4: Extract content and metadata
    extraction_result = LinkRadar::ContentArchiving::ContentExtractor.new(
      html: fetch_result.data[:body],
      url: fetch_result.data[:final_url]
    ).call
    if extraction_result.failure?
      return handle_extraction_failure(extraction_result)
    end

    # Step 5: Sanitize HTML content
    sanitization_result = LinkRadar::ContentArchiving::HtmlSanitizer.new(
      extraction_result.data[:content_html]
    ).call
    if sanitization_result.failure?
      return handle_sanitization_failure(sanitization_result)
    end

    # Step 6: Store results in archive
    store_archive_content(
      extraction_result.data.merge(content_html: sanitization_result.data),
      fetch_result.data[:final_url]
    )

    # Step 7: Transition to success
    @archive.transition_to!(:success)
  end

  # Handles URL validation failures
  #
  # Determines if failure is due to blocked URL (private IP) or invalid URL,
  # and transitions to appropriate state.
  #
  # @param result [LinkRadar::Result] the failed validation result
  # @return [void]
  def handle_validation_failure(result)
    error_message = result.errors.first
    metadata = result.data || {}

    # Check if this is a SSRF block (private IP)
    if error_message.include?("private IP") || metadata[:validation_reason] == "private_ip"
      @archive.transition_to!(
        :blocked,
        error_message: error_message,
        validation_reason: "private_ip"
      )
    else
      # Other validation failures (invalid scheme, malformed URL, DNS failure)
      @archive.transition_to!(
        :invalid_url,
        error_message: error_message,
        validation_reason: "invalid_url"
      )
    end

    # Update error_message column for easy querying
    @archive.update(error_message: error_message)
  end

  # Handles HTTP fetch failures
  #
  # @param result [LinkRadar::Result] the failed fetch result
  # @return [void]
  def handle_fetch_failure(result)
    error_message = result.errors.first
    metadata = result.data || {}

    # Check for SSRF attempt detected during redirect
    if error_message.include?("private IP")
      @archive.transition_to!(
        :blocked,
        error_message: error_message,
        validation_reason: "private_ip_redirect"
      )
    else
      # Other fetch failures (404, 5xx, size limit, etc.)
      @archive.transition_to!(
        :failed,
        error_message: error_message,
        http_status: metadata[:http_status],
        retry_count: executions
      )
    end

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
      error_message: error_message,
      retry_count: executions
    )

    @archive.update(error_message: error_message)
  end

  # Handles HTML sanitization failures
  #
  # @param result [LinkRadar::Result] the failed sanitization result
  # @return [void]
  def handle_sanitization_failure(result)
    error_message = result.errors.first

    @archive.transition_to!(
      :failed,
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
      error_message: error_message,
      retry_count: executions
    )

    @archive.update(error_message: error_message)
  end

  # Stores extracted content and metadata in archive
  #
  # @param extracted_data [Hash] the extracted content and metadata
  # @param final_url [String] the final URL after redirects
  # @return [void]
  def store_archive_content(extracted_data, final_url)
    @archive.update!(
      content_html: extracted_data[:content_html],
      content_text: extracted_data[:content_text],
      title: extracted_data[:title],
      description: extracted_data[:description],
      image_url: extracted_data[:image_url],
      metadata: extracted_data[:metadata] || {},
      fetched_at: Time.current
    )
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

- [ ] Test invalid URL: Create link with `url: "ftp://example.com"`, run job, verify `invalid_url` state
- [ ] Test private IP: Create link with `url: "http://192.168.1.1"`, run job, verify `blocked` state
- [ ] Test 404: Create link with `url: "https://example.com/nonexistent"`, run job, verify `failed` state

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

- [ ] **Test 1: Successful archival**
  - Create link: `link = Link.create!(url: "https://example.com", submitted_url: "https://example.com")`
  - Verify archive created: `link.content_archive.present?`
  - Verify initial state: `link.content_archive.current_state == "pending"`
  - Wait for job to complete (or run synchronously): `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify success state: `link.content_archive.reload.current_state == "success"`
  - Verify content stored: `link.content_archive.content_html.present?`
  - Verify metadata: `link.content_archive.metadata.present?`
  - Verify transitions: `link.content_archive.content_archive_transitions.order(created_at: :asc).pluck(:to_state)`
    - Should show: `["pending", "processing", "success"]`

- [ ] **Test 2: Private IP blocked**
  - Create link: `link = Link.create!(url: "http://192.168.1.1", submitted_url: "http://192.168.1.1")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify blocked state: `link.content_archive.reload.current_state == "blocked"`
  - Verify error message: `link.content_archive.error_message`
  - Verify transitions: `["pending", "processing", "blocked"]`

- [ ] **Test 3: Invalid URL scheme**
  - Create link: `link = Link.create!(url: "ftp://example.com", submitted_url: "ftp://example.com")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify invalid_url state: `link.content_archive.reload.current_state == "invalid_url"`
  - Verify error message contains "scheme"
  - Verify transitions: `["pending", "processing", "invalid_url"]`

- [ ] **Test 4: HTTP 404 error**
  - Create link: `link = Link.create!(url: "https://example.com/nonexistent", submitted_url: "https://example.com/nonexistent")`
  - Run job: `ArchiveContentJob.perform_now(link_id: link.id)`
  - Verify failed state: `link.content_archive.reload.current_state == "failed"`
  - Verify error message contains "404"
  - Verify transitions: `["pending", "processing", "failed"]`

- [ ] **Test 5: Cascade delete**
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
  .in_state(:success, :failed, :blocked, :invalid_url, :pending, :processing)
  .group(:to_state)
  .count

# Recent archives with details
ContentArchive.includes(:link).order(created_at: :desc).limit(10).each do |archive|
  puts "Archive #{archive.id}: #{archive.current_state} - #{archive.link.url}"
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
- [ ] Job handles all failure scenarios correctly (blocked, invalid_url, failed)
- [ ] Retry logic works for timeout errors (exponential backoff)
- [ ] Link creation automatically creates archive and enqueues job
- [ ] State machine transitions tracked correctly for all scenarios
- [ ] Manual testing passes for all test cases
- [ ] Cascade delete works (link deletion removes archive and transitions)
- [ ] Sample data created and verified
- [ ] Configuration requirements documented

**Implementation Complete!** Content archival system is fully functional and integrated with Link creation.

**Future Work:** See [future.md](future.md) for Phase 2+ enhancements (JavaScript rendering, local image storage, re-fetch capability).

