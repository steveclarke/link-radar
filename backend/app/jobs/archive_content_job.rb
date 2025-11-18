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
