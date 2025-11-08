# frozen_string_literal: true

module LinkRadar
  module ContentArchiving
    # Validates URLs for safe content fetching with SSRF protection
    #
    # This service validates URLs before they are fetched to prevent:
    # - SSRF attacks (accessing internal network resources)
    # - Non-HTTP/HTTPS schemes (file://, ftp://, etc.)
    # - Invalid or malformed URLs
    #
    # @example Valid URL
    #   result = UrlValidator.new("https://example.com/page").call
    #   result.success? # => true
    #   result.data     # => "https://example.com/page"
    #
    # @example Invalid scheme (file://)
    #   result = UrlValidator.new("file:///etc/passwd").call
    #   result.failure? # => true
    #   result.errors   # => ["URL scheme must be http or https"]
    #
    # @example Private IP (SSRF blocked)
    #   result = UrlValidator.new("http://192.168.1.1/admin").call
    #   result.failure? # => true
    #   result.errors   # => ["URL resolves to private IP address (SSRF protection)"]
    #
    class UrlValidator
      include LinkRadar::Resultable

      # Allowed URL schemes
      ALLOWED_SCHEMES = %w[http https].freeze

      # @param url [String] the URL to validate
      def initialize(url)
        @url = url
      end

      # Validates the URL
      #
      # @return [LinkRadar::Result] success with normalized URL or failure with errors
      def call
        parsed_url = parse_url
        return parsed_url if parsed_url.failure?

        scheme_validation_result = validate_scheme(parsed_url.data)
        return scheme_validation_result if scheme_validation_result.failure?

        private_ip_check_result = check_for_private_ips(parsed_url.data)
        return private_ip_check_result if private_ip_check_result.failure?

        success(parsed_url.data.to_s)
      rescue => e
        failure("URL validation error: #{e.message}", {url: url})
      end

      private

      attr_reader :url

      # Parses the URL using Addressable
      #
      # @return [LinkRadar::Result] success with parsed URL or failure with FetchError
      def parse_url
        parsed = Addressable::URI.parse(url)

        if parsed.nil? || parsed.host.nil?
          error = FetchError.new(
            error_code: :invalid_url,
            error_message: "Invalid URL format",
            url: url
          )
          return failure(error.error_message, error)
        end

        success(parsed)
      rescue Addressable::URI::InvalidURIError => e
        error = FetchError.new(
          error_code: :invalid_url,
          error_message: "Malformed URL: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Validates URL scheme is http or https
      #
      # @param parsed_url [Addressable::URI] the parsed URL
      # @return [LinkRadar::Result] success or failure with FetchError
      def validate_scheme(parsed_url)
        unless ALLOWED_SCHEMES.include?(parsed_url.scheme&.downcase)
          error = FetchError.new(
            error_code: :invalid_url,
            error_message: "URL scheme must be http or https",
            url: parsed_url.to_s,
            details: {
              scheme: parsed_url.scheme,
              allowed_schemes: ALLOWED_SCHEMES
            }
          )
          return failure(error.error_message, error)
        end

        success
      end

      # Checks if hostname resolves to private IP addresses (SSRF prevention)
      #
      # Uses private_address_check gem to resolve the hostname and check if any
      # resolved addresses are in private IP ranges. This prevents SSRF attacks
      # where malicious users could use the archival system to probe internal networks.
      #
      # The gem handles DNS resolution and checks against all RFC-defined private ranges.
      #
      # @param parsed_url [Addressable::URI] the parsed URL
      # @return [LinkRadar::Result] success or failure with FetchError if private IP detected
      def check_for_private_ips(parsed_url)
        hostname = parsed_url.host

        if PrivateAddressCheck.resolves_to_private_address?(hostname)
          error = FetchError.new(
            error_code: :blocked,
            error_message: "URL resolves to private IP address (SSRF protection)",
            url: parsed_url.to_s,
            details: {
              hostname: hostname,
              validation_reason: "private_ip"
            }
          )
          return failure(error.error_message, error)
        end

        success
      rescue SocketError => e
        # DNS resolution failed - could be invalid hostname
        error = FetchError.new(
          error_code: :invalid_url,
          error_message: "DNS resolution failed: #{e.message}",
          url: parsed_url.to_s,
          details: {hostname: hostname}
        )
        failure(error.error_message, error)
      end
    end
  end
end
