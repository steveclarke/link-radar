# frozen_string_literal: true

# State machine for tracking content archival lifecycle
#
# States:
#   - pending: Archive created, waiting for background job
#   - processing: Job actively fetching and extracting content
#   - completed: Content successfully fetched (check content_type for what was fetched)
#   - failed: Could not fetch content (check error_reason for why)
#
# Archive metadata (content_archives.metadata):
#   When completed:
#     - content_type (string): Type of content fetched (html, pdf, image, video, other)
#     - final_url (string): Final URL after redirects
#     - fetched_at (string): ISO8601 timestamp
#
# Transition metadata (content_archive_transitions.metadata):
#   When completed:
#     - fetch_duration_ms (integer): Time taken for fetch
#   When failed:
#     - error_reason (string): Why it failed (blocked, invalid_url, network_error, size_limit, etc.)
#     - error_message (string): Human-readable error details
#     - http_status (integer): HTTP response code if applicable
#     - retry_count (integer): Current retry attempt number
#
class ContentArchiveStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :processing
  state :completed
  state :failed

  transition from: :pending, to: [:processing, :failed]
  transition from: :processing, to: [:completed, :failed]
end
