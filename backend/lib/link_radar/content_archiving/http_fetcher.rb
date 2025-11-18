# frozen_string_literal: true

module LinkRadar
  module ContentArchiving
    # Value object for fetched HTTP response
    FetchedContent = Data.define(
      :body,         # Response body as string
      :status,       # HTTP status code as integer
      :final_url,    # Final URL after redirects as string
      :content_type  # Content-Type header value as string
    )

    # Self-validating HTTP client that fetches web pages with SSRF protection
    #
    # Validates initial URL and all redirect targets to prevent SSRF attacks.
    #
    # Features:
    # - Validates initial URL and all redirects for scheme and private IPs
    # - Configurable timeouts and content size limits
    # - Custom User-Agent identifying LinkRadar
    # - Returns structured FetchError for permanent failures
    # - Raises Faraday::TimeoutError for transient failures (handled by Job layer)
    #
    # @example Successful fetch
    #   result = HttpFetcher.new("https://example.com/article").call
    #   result.success? # => true
    #   result.data     # => FetchedContent instance
    #   result.data.body # => "<html>...</html>"
    #
    # @example Content too large (permanent failure)
    #   result = HttpFetcher.new("https://example.com/huge.html").call
    #   result.failure? # => true
    #   result.errors   # => ["Content size exceeds 10MB limit"]
    #   result.data     # => FetchError instance
    #   result.data.error_code # => :size_limit
    #
    # @example Redirect to private IP (SSRF blocked, permanent failure)
    #   result = HttpFetcher.new("https://evil.com/redirect-to-localhost").call
    #   result.failure? # => true
    #   result.errors   # => ["Redirect to private IP address blocked"]
    #   result.data     # => FetchError instance
    #   result.data.error_code # => :blocked
    #
    # @example Timeout (transient failure - raises for Job retry)
    #   HttpFetcher.new("https://slow-site.com").call
    #   # => raises Faraday::TimeoutError (caught by ArchiveContentJob for retry)
    #
    class HttpFetcher
      include LinkRadar::Resultable

      # HTTP redirect status codes
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze

      # @param url [String] the URL to fetch
      def initialize(url)
        @url = url
        @config = ContentArchiveConfig.new
      end

      # Fetches the URL content with validation
      #
      # @return [LinkRadar::Result] success with FetchedContent or failure with FetchError
      def call
        # Validate initial URL before making any requests
        validation_result = validate_url(url)
        return validation_result if validation_result.failure?

        # Check content size before downloading (best effort)
        length_check_result = check_content_length(url)
        return length_check_result if length_check_result.failure?

        # Perform HTTP request with redirect validation
        response = fetch_with_redirect_validation(url)
        return response if response.failure?

        final_response = response.data

        if final_response.success?
          success(
            FetchedContent.new(
              body: final_response.body,
              status: final_response.status,
              final_url: final_response.env.url.to_s,
              content_type: final_response.headers["content-type"]
            )
          )
        else
          error = FetchError.new(
            error_code: :network_error,
            error_message: "HTTP #{final_response.status}: #{final_response.reason_phrase}",
            url: url,
            http_status: final_response.status
          )
          failure(error.error_message, error)
        end
      rescue Faraday::ConnectionFailed => e
        error = FetchError.new(
          error_code: :network_error,
          error_message: "Connection failed: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      rescue Faraday::TimeoutError
        # Don't catch timeouts - let them propagate to Job layer for retry
        raise
      rescue => e
        error = FetchError.new(
          error_code: :network_error,
          error_message: "HTTP fetch error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      private

      attr_reader :url, :config

      # Validates a URL using UrlValidator
      #
      # @param url [String] the URL to validate
      # @return [LinkRadar::Result] success or failure from UrlValidator
      def validate_url(url)
        UrlValidator.new(url).call
      end

      # Fetches URL with manual redirect following and validation
      #
      # Manually follows redirects up to max_redirects, validating each
      # redirect target for SSRF before following. This prevents attacks
      # where a public domain redirects to a private IP.
      #
      # @param url [String] the URL to fetch
      # @param redirect_count [Integer] current redirect depth (for recursion)
      # @return [LinkRadar::Result] success with Faraday::Response or failure
      def fetch_with_redirect_validation(url, redirect_count = 0)
        response = http_client.get(url)

        # Check if response is a redirect
        if REDIRECT_STATUSES.include?(response.status)
          if redirect_count >= config.max_redirects
            return failure(
              "Too many redirects (exceeded #{config.max_redirects})",
              {redirect_count: redirect_count, max_redirects: config.max_redirects, final_url: url}
            )
          end

          redirect_url = response.headers["location"]
          unless redirect_url
            return failure(
              "Redirect missing Location header",
              {status: response.status, current_url: url}
            )
          end

          # Resolve relative URLs to absolute
          redirect_url = resolve_redirect_url(url, redirect_url)

          # Validate redirect target before following
          validation_result = validate_url(redirect_url)
          if validation_result.failure?
            return failure(
              "Redirect to private IP address blocked (SSRF protection)",
              {redirect_url: redirect_url, current_url: url, validation_errors: validation_result.errors}
            )
          end

          # Follow the redirect
          return fetch_with_redirect_validation(redirect_url, redirect_count + 1)
        end

        # Not a redirect, return the response
        success(response)
      end

      # Resolves relative redirect URLs to absolute URLs
      #
      # @param base_url [String] the current URL
      # @param redirect_url [String] the redirect Location header value
      # @return [String] absolute redirect URL
      def resolve_redirect_url(base_url, redirect_url)
        base_uri = Addressable::URI.parse(base_url)
        redirect_uri = Addressable::URI.parse(redirect_url)

        # If redirect is absolute, use it as-is
        return redirect_url if redirect_uri.absolute?

        # Otherwise, resolve relative to base URL
        (base_uri + redirect_uri).to_s
      end

      # Builds configured Faraday HTTP client
      #
      # @return [Faraday::Connection] configured HTTP client
      def http_client
        @http_client ||= Faraday.new do |conn|
          conn.options.timeout = config.read_timeout
          conn.options.open_timeout = config.connect_timeout
          conn.headers["User-Agent"] = config.user_agent

          # Don't follow redirects automatically - we handle them manually
          # to validate each redirect target for SSRF protection
          conn.adapter Faraday.default_adapter
        end
      end

      # Checks Content-Length header to reject oversized content
      #
      # Makes a HEAD request to check Content-Length before downloading.
      # This prevents wasting bandwidth on content that exceeds size limits.
      #
      # @param url [String] the URL to check
      # @return [LinkRadar::Result] success or failure with FetchError if content too large
      def check_content_length(url)
        response = http_client.head(url)
        content_length = response.headers["content-length"]&.to_i

        if content_length && content_length > config.max_content_size
          max_size_mb = (config.max_content_size / (1024.0 * 1024)).round(1)
          error = FetchError.new(
            error_code: :size_limit,
            error_message: "Content size exceeds #{max_size_mb}MB limit",
            url: url,
            details: {
              content_length: content_length,
              max_size: config.max_content_size
            }
          )
          return failure(error.error_message, error)
        end

        success
      rescue => e
        # Fail if we can't check content size - don't risk downloading huge files
        error = FetchError.new(
          error_code: :network_error,
          error_message: "Unable to check content size: #{e.message}",
          url: url,
          details: {
            error_class: e.class.name
          }
        )
        failure(error.error_message, error)
      end
    end
  end
end
