# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::ContentArchiving::UrlValidator do
  describe "#call" do
    context "with valid URLs" do
      before do
        # Stub DNS resolution to avoid network calls in tests
        # Valid public domains should not resolve to private addresses
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).and_return(false)
      end

      it "returns success for https URLs" do
        result = described_class.new("https://example.com").call
        expect(result).to be_success
        expect(result.data).to eq("https://example.com")
      end

      it "returns success for http URLs" do
        result = described_class.new("http://example.com").call
        expect(result).to be_success
        expect(result.data).to eq("http://example.com")
      end

      it "returns normalized URL string in data" do
        result = described_class.new("https://example.com/path").call
        expect(result).to be_success
        expect(result.data).to eq("https://example.com/path")
      end

      it "preserves query parameters and fragments" do
        result = described_class.new("https://example.com/path?q=test#section").call
        expect(result).to be_success
        expect(result.data).to eq("https://example.com/path?q=test#section")
      end
    end

    context "with invalid URL schemes" do
      it "returns failure for ftp URLs" do
        result = described_class.new("ftp://example.com").call
        expect(result).to be_failure
        expect(result.errors.first).to include("URL scheme must be http or https")
      end

      it "returns failure for file URLs" do
        result = described_class.new("file:///etc/passwd").call
        expect(result).to be_failure
        expect(result.errors.first).to include("URL scheme must be http or https")
      end

      it "returns failure for javascript URLs" do
        result = described_class.new("javascript:alert(1)").call
        expect(result).to be_failure
        # javascript: URLs may be rejected at parse or scheme validation
        expect(result.errors.first).to match(/Invalid URL format|URL scheme must be http or https/)
      end

      it "returns failure for data URLs" do
        result = described_class.new("data:text/html,<script>alert(1)</script>").call
        expect(result).to be_failure
        # data: URLs may be rejected at parse or scheme validation
        expect(result.errors.first).to match(/Invalid URL format|URL scheme must be http or https/)
      end

      it "includes scheme, allowed_schemes, and url in error data" do
        result = described_class.new("ftp://example.com").call
        expect(result).to be_failure

        error = result.data
        expect(error).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(error.error_code).to eq(:invalid_url)
        expect(error.url).to eq("ftp://example.com")
        expect(error.details[:scheme]).to eq("ftp")
        expect(error.details[:allowed_schemes]).to eq(%w[http https])
      end
    end

    context "with malformed URLs" do
      it "returns failure for URLs without host" do
        result = described_class.new("http://").call
        expect(result).to be_failure
        expect(result.errors.first).to match(/Invalid URL format|Malformed URL/)
      end

      it "returns failure for completely invalid URL strings" do
        result = described_class.new("not a url at all").call
        expect(result).to be_failure
        expect(result.errors.first).to match(/Invalid URL format|Malformed URL/)
      end

      it "returns failure for URLs with invalid characters" do
        result = described_class.new("http://exa mple.com").call
        expect(result).to be_failure
        expect(result.errors.first).to include("Malformed URL")
      end

      it "includes url in error data" do
        result = described_class.new("not a url").call
        expect(result).to be_failure

        error = result.data
        expect(error).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(error.error_code).to eq(:invalid_url)
        expect(error.url).to eq("not a url")
      end
    end

    context "with private IP addresses (SSRF protection)" do
      before do
        # Stub DNS resolution to avoid network calls in tests
        # Private addresses and localhost should resolve to private IPs
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).and_return(true)
      end

      it "returns failure for localhost" do
        result = described_class.new("http://localhost/admin").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "returns failure for 127.0.0.1" do
        result = described_class.new("http://127.0.0.1/admin").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "returns failure for 192.168.x.x addresses" do
        result = described_class.new("http://192.168.1.1/router").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "returns failure for 10.x.x.x addresses" do
        result = described_class.new("http://10.0.0.1/internal").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "returns failure for 172.16.x.x - 172.31.x.x addresses" do
        result = described_class.new("http://172.16.0.1/internal").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "returns failure for IPv6 localhost (::1)" do
        result = described_class.new("http://[::1]/admin").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "returns failure for IPv6 private addresses (fc00::/7)" do
        result = described_class.new("http://[fc00::1]/internal").call
        expect(result).to be_failure
        expect(result.errors.first).to include("private IP address")
      end

      it "includes validation_reason, hostname, and url in error data" do
        result = described_class.new("http://192.168.1.1/router").call
        expect(result).to be_failure

        error = result.data
        expect(error).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(error.error_code).to eq(:blocked)
        expect(error.url).to eq("http://192.168.1.1/router")
        expect(error.details[:hostname]).to eq("192.168.1.1")
        expect(error.details[:validation_reason]).to eq("private_ip")
      end
    end

    context "with DNS resolution failures" do
      before do
        # Stub DNS resolution to raise SocketError for non-existent domains
        # This simulates what happens when DNS lookup fails
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?)
          .and_raise(SocketError.new("nodename nor servname provided, or not known"))
      end

      it "returns failure for non-existent domains" do
        result = described_class.new("http://this-definitely-does-not-exist-12345.com").call
        expect(result).to be_failure
        expect(result.errors.first).to include("DNS resolution failed")
      end

      it "includes hostname and url in error data" do
        result = described_class.new("http://this-definitely-does-not-exist-12345.com").call
        expect(result).to be_failure

        error = result.data
        expect(error).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(error.error_code).to eq(:invalid_url)
        expect(error.url).to eq("http://this-definitely-does-not-exist-12345.com")
        expect(error.details[:hostname]).to eq("this-definitely-does-not-exist-12345.com")
      end
    end

    context "with edge cases" do
      before do
        # Stub DNS resolution to avoid network calls in tests
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).and_return(false)
      end

      it "handles URLs with international domain names" do
        result = described_class.new("https://münchen.de").call
        # Should succeed (IDN domains are valid when DNS resolves)
        expect(result).to be_success
        expect(result.data).to eq("https://münchen.de")
      end

      it "handles URLs with very long paths" do
        long_path = "a" * 2000
        result = described_class.new("https://example.com/#{long_path}").call
        expect(result).to be_success
        expect(result.data).to include(long_path)
      end

      it "handles URLs with unusual but valid ports" do
        result = described_class.new("https://example.com:8443/path").call
        expect(result).to be_success
        expect(result.data).to eq("https://example.com:8443/path")
      end
    end
  end
end
