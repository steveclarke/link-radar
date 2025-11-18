# LR005 - Content Archival & Storage: Services Plan

## Overview

This plan implements the content extraction pipeline with security built into each service:
- URL validation with SSRF prevention (using private_address_check gem)
- HTTP fetching with timeouts, redirects, and size limits (self-validating)
- Content extraction orchestrating metainspector, ruby-readability, and loofah
- HTML sanitization integrated into extraction (XSS protection by default)

**Status:** ✅ Completed (2025-11-08)

**Key components created:**
- LinkRadar::ContentArchiving::UrlValidator - URL scheme and private IP validation
- LinkRadar::ContentArchiving::HttpFetcher - Self-validating HTTP client (validates initial URL and all redirects)
- LinkRadar::ContentArchiving::ContentExtractor - Metadata/content extraction with built-in sanitization (secure by default)
- Value Objects: FetchedContent, FetchError (HttpFetcher), ParsedContent, ContentMetadata, ExtractionError (ContentExtractor)

**Architecture Pattern**: 
- HttpFetcher is a **security boundary** - internally validates all URLs (initial + redirects)
- ContentExtractor is **secure by default** - automatically sanitizes HTML output (XSS protection built-in)
- All services follow LinkRadar::Resultable pattern for consistent return values
- All services return typed value objects (FetchedContent, ParsedContent, FetchError, ExtractionError) rather than hashes for type safety and clarity

**Security Model**: 
- HttpFetcher enforces SSRF protection - safe to use anywhere in codebase
- ContentExtractor enforces XSS protection - output is always sanitized and safe to store/display
- "Pit of success" design - developers cannot accidentally introduce security vulnerabilities

**References:**
- Technical Spec: [spec.md](spec.md) sections 5.3 (Service Class Architecture), 8.1 (Security)
- Requirements: [requirements.md](requirements.md) sections 2.2 (Content Extraction), 2.5 (Security)

## Table of Contents

1. [Phase 3: URL Validation Service](#1-phase-3-url-validation-service)
2. [Phase 4: HTTP Fetching Service](#2-phase-4-http-fetching-service)
3. [Phase 5: Content Extraction Service](#3-phase-5-content-extraction-service)

---

## 1. Phase 3: URL Validation Service

**Implements:** spec.md#5.3 (UrlValidator), spec.md#8.1 (SSRF Prevention), requirements.md#2.5

Creates URL validation service with SSRF attack prevention through DNS resolution and private IP detection.

**Note:** This service will be used internally by HttpFetcher to validate all URLs (initial and redirects). It can also be used standalone if needed.

### 1.1 Add private_address_check Gem

**Add to `backend/Gemfile`**:

- [x] Add gem dependency: `gem "private_address_check", "~> 0.5.0"`
- [x] Run: `bundle install`

This gem provides comprehensive RFC-compliant private IP detection, automatically maintained with updates.

### 1.2 Create UrlValidator Service

**Create `backend/lib/link_radar/content_archiving/url_validator.rb`** with full SSRF prevention logic:

- [x] Create service file with complete implementation

```ruby
# frozen_string_literal: true
module LinkRadar
  module ContentArchiving
    # Validates URLs for content archival with SSRF attack prevention
    #
    # This service performs two levels of validation:
    # 1. URL scheme validation (only http/https allowed)
    # 2. Private IP detection via DNS resolution (prevents SSRF attacks)
    #
    # SSRF Prevention: Validates URLs resolve to public IPs only.
    #
    # The gem automatically handles all RFC-defined private ranges including:
    # - IPv4: 10.0.0.0/8, 127.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12, 169.254.0.0/16
    # - IPv6: ::1/128, fc00::/7, fe80::/10
    # - Plus any new ranges added to RFC standards
    #
    # Usage: This service is primarily used internally by HttpFetcher but can
    # be called standalone if needed for URL validation without fetching.
    #
    # @example Valid URL
    #   result = UrlValidator.new("https://example.com/article").call
    #   result.success? # => true
    #   result.data     # => "https://example.com/article"
    #
    # @example Invalid scheme
    #   result = UrlValidator.new("ftp://example.com").call
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
          details: {
            hostname: hostname
          }
        )
        failure(error.error_message, error)
      end
    end
  end
end
```

### 1.3 Verification

**Test UrlValidator in Rails console:**

- [x] Start console: `rails console`
- [x] Test valid URL: `LinkRadar::ContentArchiving::UrlValidator.new("https://example.com").call`
- [x] Test invalid scheme: `LinkRadar::ContentArchiving::UrlValidator.new("ftp://example.com").call`
- [x] Test localhost: `LinkRadar::ContentArchiving::UrlValidator.new("http://localhost").call`
- [x] Test private IP: `LinkRadar::ContentArchiving::UrlValidator.new("http://192.168.1.1").call`
- [x] Test malformed URL: `LinkRadar::ContentArchiving::UrlValidator.new("not a url").call`

### 1.4 Spec Structure

**Create `backend/spec/lib/link_radar/content_archiving/url_validator_spec.rb`:**

```
describe LinkRadar::ContentArchiving::UrlValidator
  describe "#call"
    context "with valid URLs"
      it "returns success for https URLs"
      it "returns success for http URLs"
      it "returns normalized URL string in data"
      it "preserves query parameters and fragments"
    
    context "with invalid URL schemes"
      it "returns failure for ftp URLs"
      it "returns failure for file URLs"
      it "returns failure for javascript URLs"
      it "returns failure for data URLs"
      it "includes scheme, allowed_schemes, and url in error data"
    
    context "with malformed URLs"
      it "returns failure for URLs without host"
      it "returns failure for completely invalid URL strings"
      it "returns failure for URLs with invalid characters"
      it "includes url in error data"
    
    context "with private IP addresses (SSRF protection)"
      it "returns failure for localhost"
      it "returns failure for 127.0.0.1"
      it "returns failure for 192.168.x.x addresses"
      it "returns failure for 10.x.x.x addresses"
      it "returns failure for 172.16.x.x - 172.31.x.x addresses"
      it "returns failure for IPv6 localhost (::1)"
      it "returns failure for IPv6 private addresses (fc00::/7)"
      it "includes validation_reason, hostname, and url in error data"
    
    context "with DNS resolution failures"
      it "returns failure for non-existent domains"
      it "includes hostname and url in error data"
    
    context "with edge cases"
      it "handles URLs with international domain names"
      it "handles URLs with very long paths"
      it "handles URLs with unusual but valid ports"
```

---

## 2. Phase 4: HTTP Fetching Service

**Implements:** spec.md#5.3 (HttpFetcher), requirements.md#2.2 (Content Extraction Pipeline)

Creates self-validating HTTP client service using Faraday with timeout, redirect, and size limit configurations.

**Security Boundary:** HttpFetcher is the security boundary for external requests. It internally validates:
1. Initial URL before fetching
2. Every redirect target before following

This ensures HttpFetcher is safe to use anywhere in the codebase - it cannot be used to make requests to private IPs.

### 2.1 Create HttpFetcher Service

**Create `backend/lib/link_radar/content_archiving/http_fetcher.rb`**:

- [x] Create service file

```ruby
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
```

### 2.2 Verification

**Test HttpFetcher in Rails console:**

- [x] Test real URL: `result = LinkRadar::ContentArchiving::HttpFetcher.new("https://example.com").call`
- [x] Verify response is FetchedContent: `result.data.class.name` (should be "LinkRadar::ContentArchiving::FetchedContent")
- [x] Check fields: `result.data.body`, `result.data.status`, `result.data.final_url`, `result.data.content_type`
- [x] Test 404: `LinkRadar::ContentArchiving::HttpFetcher.new("https://example.com/nonexistent").call`
- [x] Test redirect: `LinkRadar::ContentArchiving::HttpFetcher.new("http://example.com").call` (should follow to https)
- [x] **Test SSRF protection:**
  - [x] Test private IP blocked: `LinkRadar::ContentArchiving::HttpFetcher.new("http://192.168.1.1").call`
  - [x] Verify returns failure with "private IP" error
  - [x] Test localhost blocked: `LinkRadar::ContentArchiving::HttpFetcher.new("http://localhost").call`
  - [x] Verify returns failure with "private IP" error

**Note:** HttpFetcher validates all URLs internally, so it's safe to use anywhere in the codebase.

### 2.3 Spec Structure

**Create `backend/spec/lib/link_radar/content_archiving/http_fetcher_spec.rb`:**

```
describe LinkRadar::ContentArchiving::HttpFetcher
  describe "#call"
    context "with successful HTTP requests"
      it "returns success with FetchedContent value object"
      it "FetchedContent includes body, status, final_url, and content_type"
      it "fetches HTML content successfully"
      it "handles 200 OK responses"
      it "includes final URL in response data"
      it "includes content type in response data"
    
    context "with HTTP errors"
      it "returns failure for 404 Not Found"
      it "returns failure for 500 Internal Server Error"
      it "returns failure for 403 Forbidden"
      it "includes http_status and url in error data"
    
    context "with redirects"
      it "follows 301 redirects"
      it "follows 302 redirects"
      it "follows 307 redirects"
      it "follows 308 redirects"
      it "validates each redirect target"
      it "returns final URL after following redirects"
      it "handles relative redirect URLs"
      it "handles absolute redirect URLs"
    
    context "with too many redirects"
      it "returns failure when exceeding max_redirects"
      it "includes redirect_count, max_redirects, and final_url in error data"
    
    context "with invalid redirects"
      it "returns failure when Location header is missing"
      it "includes status and current_url in error data"
    
    context "with SSRF protection"
      it "blocks initial URL with private IP"
      it "blocks redirect to localhost"
      it "blocks redirect to 192.168.x.x"
      it "blocks redirect to 10.x.x.x"
      it "blocks redirect to 127.0.0.1"
      it "blocks redirect chains that end at private IPs"
      it "includes redirect_url, current_url, and validation_errors in error data"
      it "includes url in error data for initial URL validation"
    
    context "with content size limits"
      it "returns failure when Content-Length exceeds max_content_size"
      it "includes content_length and max_size in error data"
      it "continues when HEAD request fails"
      it "continues when Content-Length header is missing"
    
    context "with timeouts (transient failures)"
      it "raises Faraday::TimeoutError on connection timeout"
      it "raises Faraday::TimeoutError on read timeout"
      it "does not catch timeout (propagates to Job layer)"
    
    context "with connection failures"
      it "returns failure when connection cannot be established"
      it "returns failure for DNS resolution errors"
      it "returns failure for SSL certificate errors"
      it "includes url in error data"
    
    context "with URL validation integration"
      it "validates URL before fetching"
      it "returns validation failure for invalid scheme"
      it "returns validation failure for malformed URL"
```

---

## 3. Phase 5: Content Extraction Service

**Implements:** spec.md#5.3 (ContentExtractor), requirements.md#2.2 (Content Extraction Pipeline)

Creates secure-by-default content extraction service with built-in HTML sanitization.

**Security Built-In:** ContentExtractor automatically sanitizes all HTML output to remove XSS vectors. This service works on HTML data (strings), not URLs, and is safe to use anywhere in the codebase - output is always sanitized.

### 3.1 Create ContentExtractor Service

**Create `backend/lib/link_radar/content_archiving/content_extractor.rb`** orchestrating metainspector and ruby-readability:

- [x] Create service file

```ruby
# frozen_string_literal: true
module LinkRadar
  module ContentArchiving
    # Value object for parsed content metadata
    #
    # Contains all metadata extracted from HTML content, including
    # OpenGraph, Twitter Cards, canonical URL, and context about
    # where the content came from.
    ContentMetadata = Data.define(
      :opengraph,      # OpenGraph metadata hash (or nil)
      :twitter,        # Twitter Card metadata hash (or nil)
      :canonical_url,  # Canonical URL string (or nil)
      :final_url,      # Final URL after redirects (source URL)
      :content_type    # Content type (always "html" for ContentExtractor)
    )

    # Value object for parsed web content
    ParsedContent = Data.define(
      :content_html,   # Main content as sanitized HTML string (XSS-safe)
      :content_text,   # Main content as plain text string
      :title,          # Page title string (or nil)
      :description,    # Page description string (or nil)
      :image_url,      # Featured image URL string (or nil)
      :metadata        # ContentMetadata instance
    )

    # Value object for extraction errors
    #
    # Provides structured error information from ContentExtractor.
    #
    # @example Extraction error
    #   error = ExtractionError.new(
    #     error_code: :extraction_error,
    #     error_message: "Failed to parse HTML",
    #     url: "https://example.com/article"
    #   )
    ExtractionError = Data.define(
      :error_code,      # Symbol: :extraction_error
      :error_message,   # String: human-readable error message
      :url,            # String: the URL being extracted
      :details         # Hash: additional context (optional)
    ) do
      def initialize(error_code:, error_message:, url:, details: {})
        super
      end
    end

    # Extracts content and metadata from HTML using multiple strategies
    #
    # Automatically sanitizes all HTML output to remove XSS vectors.
    #
    # Orchestrates three operations:
    # 1. MetaInspector - Extracts OpenGraph/Twitter Card metadata
    # 2. Ruby-Readability - Extracts main article content (Mozilla algorithm)
    # 3. Loofah - Sanitizes HTML to remove XSS vectors
    #
    # Also extracts plain text version for full-text search and LLM embeddings.
    #
    # @example Extracting from HTML
    #   result = ContentExtractor.new(
    #     html: "<html>...</html>",
    #     url: "https://example.com/article"
    #   ).call
    #
    #   parsed = result.data # => ParsedContent instance
    #   parsed.title              # => "Article Title"
    #   parsed.content_html       # => "<div>Article content...</div>"
    #   parsed.metadata.opengraph # => {"title" => "...", "image" => "..."}
    #
    class ContentExtractor
      include LinkRadar::Resultable

      # @param html [String] the HTML content to extract from
      # @param url [String] the source URL (used for relative URL resolution)
      def initialize(html:, url:)
        @html = html
        @url = url
      end

      # Extracts content and metadata from HTML
      #
      # @return [LinkRadar::Result] success with ParsedContent or failure with ExtractionError
      def call
        # Extract metadata using MetaInspector
        metadata_result = extract_metadata
        return metadata_result if metadata_result.failure?

        # Extract main content using Readability
        content_result = extract_content
        return content_result if content_result.failure?

        # Sanitize extracted HTML to remove XSS vectors
        sanitization_result = sanitize_html(content_result.data[:content_html])
        return sanitization_result if sanitization_result.failure?

        # Combine results into ParsedContent value object
        success(
          ParsedContent.new(
            content_html: sanitization_result.data,
            content_text: content_result.data[:content_text],
            title: metadata_result.data[:title],
            description: metadata_result.data[:description],
            image_url: metadata_result.data[:image_url],
            metadata: metadata_result.data[:metadata]
          )
        )
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Content extraction error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      private

      attr_reader :html, :url

      # Extracts metadata using MetaInspector
      #
      # Priority order for title/description:
      # 1. OpenGraph (og:title, og:description)
      # 2. Twitter Card (twitter:title, twitter:description)
      # 3. HTML meta tags (<title>, <meta name="description">)
      #
      # @return [LinkRadar::Result] success with metadata or failure with ExtractionError
      def extract_metadata
        # MetaInspector expects to fetch the page itself, but we already have HTML
        # Use document: option to provide pre-fetched HTML
        page = MetaInspector.new(url, document: html, warn_level: :store)

        success(
          title: extract_title(page),
          description: extract_description(page),
          image_url: extract_image(page),
          metadata: build_metadata(page)
        )
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Metadata extraction error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Extracts main content using Ruby-Readability
      #
      # Readability strips ads, navigation, footers, and extracts the main
      # article content. Also generates plain text version for search.
      #
      # @return [LinkRadar::Result] success with content or failure with ExtractionError
      def extract_content
        doc = Readability::Document.new(html, tags: %w[div p article section])

        content_html = doc.content
        content_text = extract_text_from_html(content_html)

        success(
          content_html: content_html,
          content_text: content_text
        )
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Content extraction error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Extracts title with fallback priority
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [String, nil] extracted title
      def extract_title(page)
        page.best_title || page.title
      end

      # Extracts description with fallback priority
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [String, nil] extracted description
      def extract_description(page)
        page.best_description || page.description
      end

      # Extracts preview image URL
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [String, nil] image URL
      def extract_image(page)
        page.images.best
      end

      # Builds ContentMetadata value object
      #
      # Includes OpenGraph, Twitter Card, canonical URL, plus context
      # about where the content came from (final_url, content_type).
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [ContentMetadata] structured metadata value object with all fields
      def build_metadata(page)
        ContentMetadata.new(
          opengraph: extract_opengraph(page),
          twitter: extract_twitter_card(page),
          canonical_url: page.meta_tags["canonical"]&.first,
          final_url: url,          # The URL we extracted from (already final after redirects)
          content_type: "html"     # ContentExtractor only processes HTML
        )
      end

      # Extracts OpenGraph metadata
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [Hash, nil] OpenGraph data or nil if not present
      def extract_opengraph(page)
        og_data = {}
        %w[title description image type url].each do |key|
          value = page.meta_tags["og:#{key}"]&.first
          og_data[key] = value if value
        end
        og_data.presence
      end

      # Extracts Twitter Card metadata
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [Hash, nil] Twitter Card data or nil if not present
      def extract_twitter_card(page)
        twitter_data = {}
        %w[card title description image].each do |key|
          value = page.meta_tags["twitter:#{key}"]&.first
          twitter_data[key] = value if value
        end
        twitter_data.presence
      end

      # Sanitizes HTML content to remove XSS vectors
      #
      # Uses Loofah to strip dangerous elements and attributes:
      # - Script tags and inline JavaScript
      # - Event handlers (onclick, onload, etc.)
      # - Dangerous attributes (style with javascript:, etc.)
      # - Other XSS attack vectors
      #
      # Preserves safe HTML structure for display purposes.
      #
      # @param html [String] the HTML content to sanitize
      # @return [LinkRadar::Result] success with sanitized HTML or failure with ExtractionError
      def sanitize_html(html)
        sanitized = Loofah.fragment(html).scrub!(:prune).to_s
        success(sanitized)
      rescue => e
        error = ExtractionError.new(
          error_code: :extraction_error,
          error_message: "HTML sanitization error: #{e.message}",
          url: url
        )
        failure(error.error_message, error)
      end

      # Extracts plain text from HTML for search indexing
      #
      # Uses Nokogiri to properly parse HTML and extract text content.
      # This handles script/style removal, HTML entities (&amp; → &),
      # and all edge cases that regex cannot handle correctly.
      #
      # @param html [String] the HTML content
      # @return [String] plain text content
      def extract_text_from_html(html)
        text = Nokogiri::HTML(html).text
        # Normalize whitespace
        text.gsub(/\s+/, " ").strip
      end
    end
  end
end
```

### 3.2 Verification

**Test ContentExtractor in Rails console:**

- [x] Fetch sample HTML: `html = LinkRadar::ContentArchiving::HttpFetcher.new("https://example.com").call.data.body`
- [x] Extract content: `result = LinkRadar::ContentArchiving::ContentExtractor.new(html: html, url: "https://example.com").call`
- [x] Verify result is ParsedContent: `parsed = result.data; parsed.class.name` (should be "LinkRadar::ContentArchiving::ParsedContent")
- [x] Check fields: `parsed.title`, `parsed.content_html`, `parsed.content_text`, `parsed.description`, `parsed.image_url`
- [x] Check metadata: `parsed.metadata.class.name` (should be "LinkRadar::ContentArchiving::ContentMetadata")
- [x] Check nested metadata: `parsed.metadata.opengraph`, `parsed.metadata.twitter`, `parsed.metadata.canonical_url`
- [x] **Verify sanitization:**
  - [x] Test with dangerous HTML: `html_with_xss = '<div onclick="alert()"><script>alert()</script><p>Safe content</p></div>'`
  - [x] Extract: `result = LinkRadar::ContentArchiving::ContentExtractor.new(html: html_with_xss, url: "https://example.com").call`
  - [x] Verify `result.data.content_html` has no `onclick` attribute
  - [x] Verify `result.data.content_html` has no `<script>` tags
  - [x] Verify safe content (`<p>Safe content</p>`) is preserved

### 3.3 Spec Structure

**Create `backend/spec/lib/link_radar/content_archiving/content_extractor_spec.rb`:**

```
describe LinkRadar::ContentArchiving::ContentExtractor
  describe "#call"
    context "with valid HTML and metadata"
      it "returns success with ParsedContent value object"
      it "extracts content_html using Readability"
      it "extracts content_text (plain text version)"
      it "extracts title from OpenGraph metadata"
      it "extracts title from Twitter Card metadata"
      it "falls back to HTML title tag"
      it "extracts description from OpenGraph metadata"
      it "extracts description from Twitter Card metadata"
      it "falls back to meta description tag"
      it "extracts image_url from best available source"
      it "returns ContentMetadata value object with opengraph, twitter, and canonical_url"
    
    context "with OpenGraph metadata"
      it "extracts og:title"
      it "extracts og:description"
      it "extracts og:image"
      it "extracts og:type"
      it "extracts og:url"
    
    context "with Twitter Card metadata"
      it "extracts twitter:card"
      it "extracts twitter:title"
      it "extracts twitter:description"
      it "extracts twitter:image"
    
    context "with minimal HTML"
      it "handles HTML with no metadata gracefully"
      it "handles HTML with only title"
      it "handles HTML with no Readability-extractable content"
      it "returns empty strings for missing fields"
    
    context "with content extraction"
      it "strips navigation elements"
      it "strips footer elements"
      it "strips advertisement elements"
      it "preserves article content structure"
      it "preserves paragraphs, headings, and lists"
      it "converts HTML to plain text for content_text"
      it "normalizes whitespace in plain text"
    
    context "with relative URLs"
      it "resolves relative image URLs to absolute"
      it "resolves relative canonical URLs to absolute"
    
    context "with HTML sanitization (XSS protection)"
      it "sanitizes content_html automatically"
      it "removes script tags completely"
      it "removes inline JavaScript event handlers (onclick)"
      it "removes onload event handlers"
      it "removes onmouseover event handlers"
      it "removes onerror event handlers"
      it "removes javascript: protocol in hrefs"
      it "removes javascript: protocol in style attributes"
      it "blocks <img src=x onerror=alert()>"
      it "blocks <svg onload=alert()>"
      it "blocks <iframe> tags"
      it "blocks <object> tags"
      it "blocks <embed> tags"
      it "preserves safe HTML elements (div, p, h1-h6, a, img, ul, ol, li)"
      it "preserves article and section tags"
      it "preserves text content while removing dangerous elements"
      it "handles mixed safe and dangerous content correctly"
    
    context "with sanitization error handling"
      it "returns failure when sanitization raises exception"
    
    context "with error handling"
      it "returns failure when HTML parsing fails"
      it "returns failure when extraction raises exception"
```

---

## Completion Checklist

Services complete when:
- [x] `private_address_check` gem added to Gemfile and installed
- [x] UrlValidator successfully validates URLs and blocks private IPs (using gem)
- [x] HttpFetcher is self-validating (validates initial URL + all redirects internally)
- [x] HttpFetcher can be safely used anywhere in codebase (security boundary)
- [x] ContentExtractor extracts content/metadata AND sanitizes HTML (secure by default)
- [x] ContentExtractor output is XSS-safe without additional sanitization needed
- [x] All services follow Result pattern (success/failure return values)
- [x] All services include comprehensive YARD documentation
- [x] All failures return structured error data for debugging and logging
- [x] Manual console testing passes for all services
- [x] SSRF protection verified (HttpFetcher blocks private IPs and redirect chains)
- [x] XSS protection verified (ContentExtractor sanitizes all HTML output)
- [x] RSpec tests implemented for UrlValidator following spec structure
- [x] RSpec tests implemented for HttpFetcher following spec structure
- [x] RSpec tests implemented for ContentExtractor following spec structure (including sanitization tests)
- [x] All specs passing with good coverage of success and failure cases

**Architecture Verified:**
- [x] HttpFetcher internally uses UrlValidator (dependency enforced)
- [x] ContentExtractor internally sanitizes HTML (XSS protection built-in)
- [x] Security boundaries are enforced within services (SSRF + XSS protection)
- [x] Services are secure by default - safe to use anywhere in codebase
- [x] "Pit of success" design prevents accidental security vulnerabilities

**Next:** Proceed to [plan-3-orchestration.md](plan-3-orchestration.md) to implement the background job and Link integration.

**Note:** The orchestrator (ArchiveContentJob) does NOT need to validate URLs or sanitize HTML - HttpFetcher and ContentExtractor handle security automatically.

---

## Implementation Summary (2025-11-08)

- `private_address_check` gem added and installed; WebMock configured for test stubbing.
- Implemented `LinkRadar::ContentArchiving::UrlValidator`, `HttpFetcher`, and `ContentExtractor` with their value objects (`FetchError`, `FetchedContent`, `ParsedContent`, `ContentMetadata`, `ExtractionError`).
- Comprehensive RSpec coverage added for all services, including SSRF and XSS protections.
- Manual console verification performed for each service (valid/invalid URLs, redirect chains, sanitization).
- Plan 2 services are production-ready; proceed to orchestration (Plan 3).

