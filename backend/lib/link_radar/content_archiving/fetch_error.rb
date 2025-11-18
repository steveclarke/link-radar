# frozen_string_literal: true

module LinkRadar
  module ContentArchiving
    # Value object for fetch errors
    #
    # Provides structured error information from HttpFetcher and UrlValidator
    # instead of forcing consumers to parse error message strings.
    #
    # @example Network error
    #   error = FetchError.new(
    #     error_code: :network_error,
    #     error_message: "HTTP 404: Not Found",
    #     url: "https://example.com/missing",
    #     http_status: 404
    #   )
    #
    # @example SSRF blocked
    #   error = FetchError.new(
    #     error_code: :blocked,
    #     error_message: "URL resolves to private IP address",
    #     url: "http://192.168.1.1",
    #     details: { hostname: "192.168.1.1" }
    #   )
    FetchError = Data.define(
      :error_code,      # Symbol: :blocked, :invalid_url, :network_error, :size_limit
      :error_message,   # String: human-readable error message
      :url,            # String: the URL that failed
      :http_status,    # Integer: HTTP status code (optional, nil for non-HTTP errors)
      :details         # Hash: additional context (optional)
    ) do
      def initialize(error_code:, error_message:, url:, http_status: nil, details: {})
        super
      end
    end
  end
end
