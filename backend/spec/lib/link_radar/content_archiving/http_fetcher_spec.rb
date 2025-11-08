# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::ContentArchiving::HttpFetcher do
  let(:url) { "https://example.com/article" }
  let(:config) do
    instance_double(
      ContentArchiveConfig,
      max_redirects: 3,
      max_content_size: 10.megabytes,
      connect_timeout: 5,
      read_timeout: 5,
      user_agent: "LinkRadar/1.0 (+https://linkradar.test)"
    )
  end

  before do
    allow(ContentArchiveConfig).to receive(:new).and_return(config)
    allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).and_return(false)
  end

  describe "#call" do
    context "with successful HTTP requests" do
      let(:body) { "<html><body>Hello</body></html>" }

      before do
        stub_request(:head, url).to_return(status: 200, headers: {"Content-Length" => "1024"})
        stub_request(:get, url).to_return(status: 200, headers: {"Content-Type" => "text/html"}, body: body)
      end

      it "returns success with FetchedContent value object" do
        result = described_class.new(url).call

        expect(result).to be_success
        expect(result.data).to be_a(LinkRadar::ContentArchiving::FetchedContent)
      end

      it "includes body, status, final_url, and content_type" do
        result = described_class.new(url).call
        content = result.data

        expect(content.body).to eq(body)
        expect(content.status).to eq(200)
        expect(content.final_url).to eq(url)
        expect(content.content_type).to eq("text/html")
      end
    end

    context "with HTTP errors" do
      shared_examples "http error handling" do |status, reason|
        it "returns failure for #{status} #{reason}" do
          stub_request(:head, url).to_return(status: 200)
          stub_request(:get, url).to_return(status: [status, reason])

          result = described_class.new(url).call

          expect(result).to be_failure
          expect(result.errors.first).to eq("HTTP #{status}: #{reason}")
          expect(result.data).to be_a(LinkRadar::ContentArchiving::FetchError)
          expect(result.data.error_code).to eq(:network_error)
          expect(result.data.http_status).to eq(status)
          expect(result.data.url).to eq(url)
        end
      end

      include_examples "http error handling", 404, "Not Found"
      include_examples "http error handling", 500, "Internal Server Error"
      include_examples "http error handling", 403, "Forbidden"
    end

    context "with redirects" do
      let(:redirect_url) { "https://example.com/final" }
      let(:final_body) { "<html>Redirected</html>" }

      before do
        stub_request(:head, url).to_return(status: 200)
        stub_request(:get, redirect_url).to_return(status: 200, headers: {"Content-Type" => "text/html"}, body: final_body)
      end

      [301, 302, 303, 307, 308].each do |status|
        it "follows #{status} redirects" do
          stub_request(:get, url).to_return(status: status, headers: {"Location" => redirect_url})

          result = described_class.new(url).call
          content = result.data

          expect(result).to be_success
          expect(content.final_url).to eq(redirect_url)
          expect(content.body).to eq(final_body)
        end
      end

      it "validates each redirect target for SSRF protection" do
        allow(LinkRadar::ContentArchiving::UrlValidator).to receive(:new).and_call_original

        stub_request(:get, url).to_return(status: 301, headers: {"Location" => redirect_url})

        described_class.new(url).call

        expect(LinkRadar::ContentArchiving::UrlValidator).to have_received(:new).with(redirect_url)
      end

      it "handles relative redirect URLs" do
        stub_request(:get, url).to_return(status: 302, headers: {"Location" => "/redirected"})
        stub_request(:get, "https://example.com/redirected").to_return(
          status: 200,
          headers: {"Content-Type" => "text/html"},
          body: final_body
        )

        result = described_class.new(url).call

        expect(result).to be_success
        expect(result.data.final_url).to eq("https://example.com/redirected")
      end

      it "returns failure when exceeding max_redirects" do
        allow(config).to receive(:max_redirects).and_return(1)

        stub_request(:get, url).to_return(status: 301, headers: {"Location" => redirect_url})
        stub_request(:get, redirect_url).to_return(status: 301, headers: {"Location" => "https://example.com/too-many"})

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to include("Too many redirects")
        expect(result.data).to include(:redirect_count, :max_redirects, :final_url)
      end

      it "returns failure when Location header is missing" do
        stub_request(:get, url).to_return(status: 302, headers: {})

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Redirect missing Location header")
        expect(result.data).to eq({status: 302, current_url: url})
      end
    end

    context "with SSRF protection" do
      it "blocks initial URL with private IP" do
        private_url = "http://192.168.1.10/admin"
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).with("192.168.1.10").and_return(true)

        result = described_class.new(private_url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("URL resolves to private IP address (SSRF protection)")
        expect(result.data).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(result.data.error_code).to eq(:blocked)
      end

      it "blocks redirect to private IP" do
        private_redirect = "http://127.0.0.1/secret"
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?) { |hostname| hostname == "127.0.0.1" }

        stub_request(:head, url).to_return(status: 200)
        stub_request(:get, url).to_return(status: 301, headers: {"Location" => private_redirect})

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Redirect to private IP address blocked (SSRF protection)")
        expect(result.data).to include(
          redirect_url: private_redirect,
          current_url: url
        )
      end

      it "blocks redirect chains that end at private IPs" do
        intermediate_url = "https://example.com/jump"
        private_redirect = "http://10.0.0.1/internal"

        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).and_return(false)
        allow(PrivateAddressCheck).to receive(:resolves_to_private_address?).with("10.0.0.1").and_return(true)

        stub_request(:head, url).to_return(status: 200)
        stub_request(:get, url).to_return(status: 301, headers: {"Location" => intermediate_url})
        stub_request(:get, intermediate_url).to_return(status: 302, headers: {"Location" => private_redirect})

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Redirect to private IP address blocked (SSRF protection)")
        expect(result.data[:redirect_url]).to eq(private_redirect)
        expect(result.data[:current_url]).to eq(intermediate_url)
      end
    end

    context "with content size limits" do
      it "returns failure when Content-Length exceeds max_content_size" do
        allow(config).to receive(:max_content_size).and_return(1024)

        stub_request(:head, url).to_return(status: 200, headers: {"Content-Length" => "4096"})

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Content size exceeds 0.0MB limit")
        expect(result.data).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(result.data.error_code).to eq(:size_limit)
        expect(result.data.details).to include(:content_length, :max_size)
      end

      it "continues when Content-Length header is missing" do
        stub_request(:head, url).to_return(status: 200, headers: {})
        stub_request(:get, url).to_return(status: 200, headers: {"Content-Type" => "text/html"}, body: "ok")

        result = described_class.new(url).call

        expect(result).to be_success
      end
    end

    context "with timeouts" do
      it "returns failure when HEAD request times out" do
        stub_request(:head, url).to_raise(Faraday::TimeoutError.new("execution expired"))

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Unable to check content size: execution expired")
        expect(result.data.error_code).to eq(:network_error)
      end

      it "raises Faraday::TimeoutError on read timeout" do
        stub_request(:head, url).to_return(status: 200)
        stub_request(:get, url).to_raise(Faraday::TimeoutError.new("read timed out"))

        expect { described_class.new(url).call }.to raise_error(Faraday::TimeoutError)
      end
    end

    context "with connection failures" do
      it "returns failure when connection cannot be established" do
        error = Faraday::ConnectionFailed.new("connection refused")
        stub_request(:head, url).to_raise(error)

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Unable to check content size: connection refused")
        expect(result.data).to be_a(LinkRadar::ContentArchiving::FetchError)
        expect(result.data.error_code).to eq(:network_error)
      end

      it "returns failure for SSL certificate errors" do
        stub_request(:head, url).to_raise(Faraday::SSLError.new("cert verify failed"))

        result = described_class.new(url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Unable to check content size: cert verify failed")
        expect(result.data.error_code).to eq(:network_error)
      end
    end

    context "with URL validation integration" do
      it "returns validation failure for invalid scheme" do
        result = described_class.new("ftp://example.com/resource").call

        expect(result).to be_failure
        expect(result.errors.first).to eq("URL scheme must be http or https")
      end

      it "returns validation failure for malformed URL" do
        result = described_class.new("http://").call

        expect(result).to be_failure
        expect(result.errors.first).to match(/Invalid URL format|Malformed URL/)
      end
    end
  end
end
