# frozen_string_literal: true

class CoreConfig < ApplicationConfig
  attr_config(
    :api_key,
    :cors_origins,
    :log_level,
    app_env: Rails.env,
    frontend_url: "http://localhost:9000"
  )

  # Override cors_origins to automatically convert string patterns to regex objects
  #
  # Supports two formats:
  #   1. Exact match: "http://localhost:3000"
  #   2. Regex pattern: "/pattern/" (wrapped in forward slashes)
  #
  # Regex examples:
  #   - "/chrome-extension://.*/" matches any Chrome extension
  #   - "/https://.*\.example\.com/" matches any subdomain of example.com
  #
  # Note: Forward slashes in the pattern don't need escaping since we use Regexp.new()
  def cors_origins
    super.map do |origin|
      if (match = origin.match(/^\/(.+)\/$/))
        Regexp.new(match[1])
      else
        origin
      end
    end
  end
end
