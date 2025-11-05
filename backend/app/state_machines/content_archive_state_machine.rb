# frozen_string_literal: true

# State machine for tracking content archival lifecycle
#
# States:
#   - pending: Archive created, waiting for background job
#   - processing: Job actively fetching and extracting content
#   - success: Content successfully archived
#   - failed: Failed after all retries exhausted
#   - invalid_url: URL validation failed (invalid scheme, malformed)
#   - blocked: URL blocked for security (private IP, SSRF)
#
# Transition metadata stored in content_archive_transitions.metadata:
#   - error_message (string): Error details for failures
#   - validation_reason (string): Why URL was blocked/invalid
#   - fetch_duration_ms (integer): Time taken for successful fetches
#   - retry_count (integer): Current retry attempt number
#   - http_status (integer): HTTP response code if applicable
#
class ContentArchiveStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :processing
  state :success
  state :failed
  state :invalid_url
  state :blocked

  # Define allowed transitions per spec.md#3.2
  transition from: :pending, to: [:processing, :blocked, :invalid_url]
  transition from: :processing, to: [:success, :failed, :blocked]
end
