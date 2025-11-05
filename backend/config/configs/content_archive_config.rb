# frozen_string_literal: true

# Configuration for content archival system
#
# Manages timeouts, limits, retry settings, and User-Agent for web content fetching.
# Values can be set via environment variables, YAML file, or Rails credentials.
#
# @example Accessing configuration
#   ContentArchiveConfig.connect_timeout  # => 10
#   ContentArchiveConfig.user_agent       # => "LinkRadar/1.0 (+https://github.com/...)"
#
# @example Environment variables
#   CONTENT_ARCHIVE_CONNECT_TIMEOUT=15
#   CONTENT_ARCHIVE_USER_AGENT_CONTACT_URL=https://linkradar.example.com
#
class ContentArchiveConfig < ApplicationConfig
  attr_config(
    :user_agent_contact_url,    # contact URL for User-Agent header

    # HTTP timeouts
    connect_timeout: 10,        # seconds to wait for connection
    read_timeout: 15,           # seconds to wait for response

    # Fetch limits
    max_redirects: 5,           # maximum redirect hops to follow
    max_content_size: 10.megabytes,  # 10MB in bytes

    # Retry configuration
    max_retries: 3,             # total retry attempts (including initial)
    retry_backoff_base: 2,      # backoff base in seconds (2s, 4s, 8s...)

    # Feature flag
    enabled: true               # global enable/disable for archival
  )

  # Require user_agent_contact_url in production
  required :user_agent_contact_url, env: :production

  # Builds complete User-Agent string for HTTP requests
  #
  # Format: "LinkRadar/1.0 (+{contact_url})"
  #
  # @return [String] formatted User-Agent header value
  # @example
  #   ContentArchiveConfig.user_agent
  #   # => "LinkRadar/1.0 (+https://github.com/username/link-radar)"
  def user_agent
    "LinkRadar/1.0 (+#{user_agent_contact_url})"
  end
end
