# LR005 - Content Archival & Storage: Services Plan

## Overview

This plan implements the content extraction pipeline as independent service classes:
- URL validation with SSRF prevention (novel DNS resolution logic)
- HTTP fetching with timeouts, redirects, and size limits
- Content extraction orchestrating metainspector and ruby-readability
- HTML sanitization for XSS protection

**Key components created:**
- LinkRadar::ContentArchiving::UrlValidator - URL scheme and private IP validation
- LinkRadar::ContentArchiving::HttpFetcher - Faraday-based HTTP client
- LinkRadar::ContentArchiving::ContentExtractor - Metadata and content extraction
- LinkRadar::ContentArchiving::HtmlSanitizer - Loofah-based sanitization

**Pattern**: All services follow LinkRadar::Resultable pattern for consistent return values.

**References:**
- Technical Spec: [spec.md](spec.md) sections 5.3 (Service Class Architecture), 8.1 (Security)
- Requirements: [requirements.md](requirements.md) sections 2.2 (Content Extraction), 2.5 (Security)

## Table of Contents

1. [Phase 3: URL Validation Service](#1-phase-3-url-validation-service)
2. [Phase 4: HTTP Fetching Service](#2-phase-4-http-fetching-service)
3. [Phase 5: Content Processing Services](#3-phase-5-content-processing-services)

---

## 1. Phase 3: URL Validation Service

**Implements:** spec.md#5.3 (UrlValidator), spec.md#8.1 (SSRF Prevention), requirements.md#2.5

Creates URL validation service with SSRF attack prevention through DNS resolution and private IP detection.

### 1.1 Create UrlValidator Service

**Create `backend/lib/link_radar/content_archiving/url_validator.rb`** with full SSRF prevention logic:

- [ ] Create service file with complete implementation

```ruby
# frozen_string_literal: true

require "addressable/uri"
require "resolv"

module LinkRadar
  module ContentArchiving
    # Validates URLs for content archival with SSRF attack prevention
    #
    # This service performs two levels of validation:
    # 1. URL scheme validation (only http/https allowed)
    # 2. Private IP detection via DNS resolution (prevents SSRF attacks)
    #
    # SSRF Prevention Strategy:
    # Resolves the hostname to IP addresses and checks if any resolve to
    # private/internal IP ranges. This prevents attackers from using the
    # archival system to probe internal networks or services.
    #
    # Blocked IP ranges:
    # - 10.0.0.0/8 (private networks)
    # - 127.0.0.0/8 (loopback)
    # - 192.168.0.0/16 (private networks)
    # - 172.16.0.0/12 (private networks)
    # - 169.254.0.0/16 (link-local)
    # - ::1/128 (IPv6 loopback)
    # - fc00::/7 (IPv6 private)
    # - fe80::/10 (IPv6 link-local)
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

      # Private IP ranges for SSRF prevention (IPv4)
      PRIVATE_IP_RANGES = [
        IPAddr.new("10.0.0.0/8"),      # Private network
        IPAddr.new("127.0.0.0/8"),     # Loopback
        IPAddr.new("192.168.0.0/16"),  # Private network
        IPAddr.new("172.16.0.0/12"),   # Private network
        IPAddr.new("169.254.0.0/16")   # Link-local
      ].freeze

      # Private IP ranges for SSRF prevention (IPv6)
      PRIVATE_IPV6_RANGES = [
        IPAddr.new("::1/128"),   # Loopback
        IPAddr.new("fc00::/7"),  # Unique local address
        IPAddr.new("fe80::/10")  # Link-local
      ].freeze

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

        scheme_validation = validate_scheme(parsed_url.data)
        return scheme_validation if scheme_validation.failure?

        private_ip_check = check_for_private_ips(parsed_url.data)
        return private_ip_check if private_ip_check.failure?

        success(parsed_url.data.to_s)
      rescue => e
        failure("URL validation error: #{e.message}")
      end

      private

      # Parses the URL using Addressable
      #
      # @return [LinkRadar::Result] success with parsed URL or failure with error
      def parse_url
        parsed = Addressable::URI.parse(@url)

        if parsed.nil? || parsed.host.nil?
          return failure("Invalid URL format")
        end

        success(parsed)
      rescue Addressable::URI::InvalidURIError => e
        failure("Malformed URL: #{e.message}")
      end

      # Validates URL scheme is http or https
      #
      # @param parsed_url [Addressable::URI] the parsed URL
      # @return [LinkRadar::Result] success or failure with error
      def validate_scheme(parsed_url)
        unless ALLOWED_SCHEMES.include?(parsed_url.scheme&.downcase)
          return failure("URL scheme must be http or https")
        end

        success
      end

      # Checks if URL resolves to private IP addresses (SSRF prevention)
      #
      # Resolves the hostname to IP addresses and checks each against
      # private IP ranges. This prevents SSRF attacks where malicious users
      # could use the archival system to probe internal networks.
      #
      # @param parsed_url [Addressable::URI] the parsed URL
      # @return [LinkRadar::Result] success or failure if private IP detected
      def check_for_private_ips(parsed_url)
        hostname = parsed_url.host

        # Resolve hostname to IP addresses
        addresses = resolve_hostname(hostname)

        # Check each resolved IP against private ranges
        addresses.each do |ip_string|
          ip = IPAddr.new(ip_string)

          if private_ip?(ip)
            return failure(
              "URL resolves to private IP address (SSRF protection)",
              {validation_reason: "private_ip", resolved_ip: ip_string}
            )
          end
        end

        success
      rescue SocketError => e
        # DNS resolution failed - could be invalid hostname
        failure("DNS resolution failed: #{e.message}")
      end

      # Resolves hostname to IP addresses
      #
      # @param hostname [String] the hostname to resolve
      # @return [Array<String>] array of IP address strings
      def resolve_hostname(hostname)
        Resolv::DNS.open do |dns|
          # Try IPv4 first
          ipv4_addresses = dns.getresources(hostname, Resolv::DNS::Resource::IN::A)
            .map { |r| r.address.to_s }

          # Try IPv6 if no IPv4 found
          ipv6_addresses = if ipv4_addresses.empty?
            dns.getresources(hostname, Resolv::DNS::Resource::IN::AAAA)
              .map { |r| r.address.to_s }
          else
            []
          end

          ipv4_addresses + ipv6_addresses
        end
      end

      # Checks if an IP address is in a private range
      #
      # @param ip [IPAddr] the IP address to check
      # @return [Boolean] true if IP is private, false otherwise
      def private_ip?(ip)
        if ip.ipv4?
          PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
        else
          PRIVATE_IPV6_RANGES.any? { |range| range.include?(ip) }
        end
      end
    end
  end
end
```

### 1.2 Verification

**Test UrlValidator in Rails console:**

- [ ] Start console: `rails console`
- [ ] Test valid URL: `LinkRadar::ContentArchiving::UrlValidator.new("https://example.com").call`
- [ ] Test invalid scheme: `LinkRadar::ContentArchiving::UrlValidator.new("ftp://example.com").call`
- [ ] Test localhost: `LinkRadar::ContentArchiving::UrlValidator.new("http://localhost").call`
- [ ] Test private IP: `LinkRadar::ContentArchiving::UrlValidator.new("http://192.168.1.1").call`
- [ ] Test malformed URL: `LinkRadar::ContentArchiving::UrlValidator.new("not a url").call`

---

## 2. Phase 4: HTTP Fetching Service

**Implements:** spec.md#5.3 (HttpFetcher), requirements.md#2.2 (Content Extraction Pipeline)

Creates HTTP client service using Faraday with timeout, redirect, and size limit configurations.

### 2.1 Create HttpFetcher Service

**Create `backend/lib/link_radar/content_archiving/http_fetcher.rb`**:

- [ ] Create service file

```ruby
# frozen_string_literal: true

require "faraday"

module LinkRadar
  module ContentArchiving
    # Fetches web page content via HTTP with timeouts and size limits
    #
    # Uses Faraday HTTP client configured with:
    # - Connect and read timeouts from ContentArchiveConfig
    # - Automatic redirect following (up to max_redirects)
    # - Content-Length header checking before download
    # - Custom User-Agent identifying LinkRadar
    #
    # @example Successful fetch
    #   result = HttpFetcher.new("https://example.com/article").call
    #   result.success? # => true
    #   result.data     # => {body: "<html>...</html>", status: 200, final_url: "..."}
    #
    # @example File too large
    #   result = HttpFetcher.new("https://example.com/huge.html").call
    #   result.failure? # => true
    #   result.errors   # => ["File size exceeds 10MB limit"]
    #
    # @example Timeout
    #   result = HttpFetcher.new("https://slow-site.com").call
    #   result.failure? # => true
    #   result.errors   # => ["Connection timeout"]
    #
    class HttpFetcher
      include LinkRadar::Resultable

      # @param url [String] the URL to fetch
      def initialize(url)
        @url = url
        @config = ContentArchiveConfig.new
      end

      # Fetches the URL content
      #
      # @return [LinkRadar::Result] success with response data or failure with error
      #   - On success: data contains {body: String, status: Integer, final_url: String}
      #   - On failure: errors contains descriptive error message
      def call
        # Check file size before downloading
        size_check = check_file_size
        return size_check if size_check.failure?

        # Perform HTTP request
        response = http_client.get(@url)

        if response.success?
          success(
            body: response.body,
            status: response.status,
            final_url: response.env.url.to_s,
            content_type: response.headers["content-type"]
          )
        else
          failure(
            "HTTP #{response.status}: #{response.reason_phrase}",
            {http_status: response.status}
          )
        end
      rescue Faraday::ConnectionFailed => e
        failure("Connection failed: #{e.message}")
      rescue Faraday::TimeoutError => e
        failure("Connection timeout")
      rescue Faraday::TooManyRedirectsError => e
        failure("Too many redirects (exceeded #{@config.max_redirects})")
      rescue => e
        failure("HTTP fetch error: #{e.message}")
      end

      private

      # Builds configured Faraday HTTP client
      #
      # @return [Faraday::Connection] configured HTTP client
      def http_client
        @http_client ||= Faraday.new do |conn|
          conn.options.timeout = @config.read_timeout
          conn.options.open_timeout = @config.connect_timeout
          conn.headers["User-Agent"] = @config.user_agent

          # Follow redirects up to max_redirects
          conn.use Faraday::FollowRedirects::Middleware,
            limit: @config.max_redirects

          conn.adapter Faraday.default_adapter
        end
      end

      # Checks Content-Length header to reject oversized files
      #
      # Makes a HEAD request to check Content-Length before downloading.
      # This prevents wasting bandwidth on files that exceed size limits.
      #
      # @return [LinkRadar::Result] success or failure if file too large
      def check_file_size
        response = http_client.head(@url)
        content_length = response.headers["content-length"]&.to_i

        if content_length && content_length > @config.max_file_size
          max_mb = @config.max_file_size / 1_048_576
          return failure(
            "File size exceeds #{max_mb}MB limit",
            {content_length: content_length, max_size: @config.max_file_size}
          )
        end

        success
      rescue => e
        # If HEAD request fails, continue with GET (some servers don't support HEAD)
        success
      end
    end
  end
end
```

### 2.2 Verification

**Test HttpFetcher in Rails console:**

- [ ] Test real URL: `LinkRadar::ContentArchiving::HttpFetcher.new("https://example.com").call`
- [ ] Verify response includes body, status, final_url
- [ ] Test 404: `LinkRadar::ContentArchiving::HttpFetcher.new("https://example.com/nonexistent").call`
- [ ] Test redirect: `LinkRadar::ContentArchiving::HttpFetcher.new("http://example.com").call` (should redirect to https)

---

## 3. Phase 5: Content Processing Services

**Implements:** spec.md#5.3 (ContentExtractor, HtmlSanitizer), requirements.md#2.2 (Content Extraction Pipeline)

Creates services for extracting content/metadata and sanitizing HTML.

### 3.1 Create ContentExtractor Service

**Create `backend/lib/link_radar/content_archiving/content_extractor.rb`** orchestrating metainspector and ruby-readability:

- [ ] Create service file

```ruby
# frozen_string_literal: true

require "metainspector"
require "ruby-readability"

module LinkRadar
  module ContentArchiving
    # Extracts content and metadata from HTML using multiple strategies
    #
    # Orchestrates two extraction libraries:
    # 1. MetaInspector - Extracts OpenGraph/Twitter Card metadata
    # 2. Ruby-Readability - Extracts main article content (Mozilla algorithm)
    #
    # Also extracts plain text version for full-text search and LLM embeddings.
    #
    # @example Extracting from HTML
    #   result = ContentExtractor.new(
    #     html: "<html>...</html>",
    #     url: "https://example.com/article"
    #   ).call
    #
    #   result.data # => {
    #   #   content_html: "<div>Article content...</div>",
    #   #   content_text: "Article content...",
    #   #   title: "Article Title",
    #   #   description: "Article description",
    #   #   image_url: "https://example.com/image.jpg",
    #   #   metadata: {
    #   #     opengraph: {...},
    #   #     twitter: {...},
    #   #     canonical_url: "..."
    #   #   }
    #   # }
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
      # @return [LinkRadar::Result] success with extracted data or failure with error
      def call
        # Extract metadata using MetaInspector
        metadata_result = extract_metadata
        return metadata_result if metadata_result.failure?

        # Extract main content using Readability
        content_result = extract_content
        return content_result if content_result.failure?

        # Combine results
        success(
          content_html: content_result.data[:content_html],
          content_text: content_result.data[:content_text],
          title: metadata_result.data[:title],
          description: metadata_result.data[:description],
          image_url: metadata_result.data[:image_url],
          metadata: metadata_result.data[:metadata]
        )
      rescue => e
        failure("Content extraction error: #{e.message}")
      end

      private

      # Extracts metadata using MetaInspector
      #
      # Priority order for title/description:
      # 1. OpenGraph (og:title, og:description)
      # 2. Twitter Card (twitter:title, twitter:description)
      # 3. HTML meta tags (<title>, <meta name="description">)
      #
      # @return [LinkRadar::Result] success with metadata or failure
      def extract_metadata
        # MetaInspector expects to fetch the page itself, but we already have HTML
        # Use document: option to provide pre-fetched HTML
        page = MetaInspector.new(@url, document: @html, warn_level: :store)

        success(
          title: extract_title(page),
          description: extract_description(page),
          image_url: extract_image(page),
          metadata: build_metadata_hash(page)
        )
      rescue => e
        failure("Metadata extraction error: #{e.message}")
      end

      # Extracts main content using Ruby-Readability
      #
      # Readability strips ads, navigation, footers, and extracts the main
      # article content. Also generates plain text version for search.
      #
      # @return [LinkRadar::Result] success with content or failure
      def extract_content
        doc = Readability::Document.new(@html, tags: %w[div p article section])

        content_html = doc.content
        content_text = extract_text_from_html(content_html)

        success(
          content_html: content_html,
          content_text: content_text
        )
      rescue => e
        failure("Content extraction error: #{e.message}")
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

      # Builds structured metadata hash
      #
      # @param page [MetaInspector::Document] the MetaInspector page object
      # @return [Hash] structured metadata with opengraph, twitter, canonical_url
      def build_metadata_hash(page)
        {
          opengraph: extract_opengraph(page),
          twitter: extract_twitter_card(page),
          canonical_url: page.meta_tags["canonical"]&.first
        }.compact
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

      # Extracts plain text from HTML for search indexing
      #
      # @param html [String] the HTML content
      # @return [String] plain text content
      def extract_text_from_html(html)
        # Simple text extraction - strip all HTML tags
        text = html.gsub(/<[^>]+>/, " ")
        # Normalize whitespace
        text.gsub(/\s+/, " ").strip
      end
    end
  end
end
```

### 3.2 Create HtmlSanitizer Service

**Create `backend/lib/link_radar/content_archiving/html_sanitizer.rb`**:

- [ ] Create service file

```ruby
# frozen_string_literal: true

require "loofah"

module LinkRadar
  module ContentArchiving
    # Sanitizes HTML content to remove potentially dangerous elements
    #
    # Uses Loofah to strip:
    # - Script tags and inline JavaScript
    # - Event handlers (onclick, onload, etc.)
    # - Dangerous attributes (style with javascript:, etc.)
    # - Other XSS vectors
    #
    # Preserves safe HTML for display purposes.
    #
    # @example Sanitizing HTML
    #   result = HtmlSanitizer.new('<div onclick="alert()">Safe content</div>').call
    #   result.data # => '<div>Safe content</div>'
    #
    class HtmlSanitizer
      include LinkRadar::Resultable

      # @param html [String] the HTML to sanitize
      def initialize(html)
        @html = html
      end

      # Sanitizes the HTML content
      #
      # @return [LinkRadar::Result] success with sanitized HTML or failure with error
      def call
        sanitized = Loofah.fragment(@html).scrub!(:prune).to_s
        success(sanitized)
      rescue => e
        failure("HTML sanitization error: #{e.message}")
      end
    end
  end
end
```

**Note on Loofah scrubbers:**
- `:prune` removes unsafe tags entirely (scripts, event handlers, etc.)
- Preserves safe HTML structure (divs, paragraphs, headings, links, images)
- Safe for storing and displaying archived content

### 3.3 Verification

**Test ContentExtractor in Rails console:**

- [ ] Fetch sample HTML: `html = LinkRadar::ContentArchiving::HttpFetcher.new("https://example.com").call.data[:body]`
- [ ] Extract content: `result = LinkRadar::ContentArchiving::ContentExtractor.new(html: html, url: "https://example.com").call`
- [ ] Verify extracted fields: `result.data.keys` (should include content_html, content_text, title, etc.)
- [ ] Check metadata structure: `result.data[:metadata]`

**Test HtmlSanitizer in Rails console:**

- [ ] Test with dangerous HTML: `LinkRadar::ContentArchiving::HtmlSanitizer.new('<div onclick="alert()">Test</div>').call`
- [ ] Verify onclick removed
- [ ] Test with script tag: `LinkRadar::ContentArchiving::HtmlSanitizer.new('<script>alert()</script><p>Safe</p>').call`
- [ ] Verify script tag removed

---

## Completion Checklist

Services complete when:
- [ ] UrlValidator successfully validates URLs and blocks private IPs
- [ ] HttpFetcher successfully fetches web pages with proper timeouts
- [ ] ContentExtractor extracts content and metadata from HTML
- [ ] HtmlSanitizer removes dangerous HTML elements
- [ ] All services follow Result pattern (success/failure return values)
- [ ] All services include comprehensive YARD documentation
- [ ] Manual console testing passes for all services

**Next:** Proceed to [plan-3-orchestration.md](plan-3-orchestration.md) to implement the background job and Link integration.

