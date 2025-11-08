# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::ContentArchiving::Archiver do
  describe "#call" do
    let(:link) { create(:link, url: "https://example.com/article") }
    let(:archive) { create(:content_archive, link: link) }
    let(:config) { instance_double(ContentArchiveConfig, enabled: true) }
    let(:archiver) { described_class.new(archive: archive, config: config) }

    context "with successful HTML archival" do
      let(:fetched_content) do
        LinkRadar::ContentArchiving::FetchedContent.new(
          body: "<html><body><h1>Hello</h1></body></html>",
          status: 200,
          final_url: "https://example.com/article",
          content_type: "text/html"
        )
      end
      let(:content_metadata) do
        LinkRadar::ContentArchiving::ContentMetadata.new(
          opengraph: {"title" => "OG Title"},
          twitter: {"title" => "Twitter Title"},
          canonical_url: "https://example.com/article",
          final_url: "https://example.com/article",
          content_type: "html"
        )
      end
      let(:parsed_content) do
        LinkRadar::ContentArchiving::ParsedContent.new(
          content_html: "<div><h1>Hello</h1></div>",
          content_text: "Hello",
          title: "OG Title",
          description: "Best description",
          image_url: "https://example.com/image.png",
          metadata: content_metadata
        )
      end
      let(:fetcher) do
        instance_double(
          LinkRadar::ContentArchiving::HttpFetcher,
          call: LinkRadar::Result.success(fetched_content)
        )
      end
      let(:extractor) do
        instance_double(
          LinkRadar::ContentArchiving::ContentExtractor,
          call: LinkRadar::Result.success(parsed_content)
        )
      end

      before do
        allow(LinkRadar::ContentArchiving::HttpFetcher)
          .to receive(:new).with(link.url).and_return(fetcher)

        allow(LinkRadar::ContentArchiving::ContentExtractor)
          .to receive(:new)
          .with(html: fetched_content.body, url: fetched_content.final_url)
          .and_return(extractor)
      end

      it "transitions the archive from pending to processing to completed" do
        archiver.call
        archive.reload

        transitions = archive.content_archive_transitions.order(:sort_key).pluck(:to_state)
        expect(transitions).to eq(%w[processing completed])
        expect(archive.current_state).to eq("completed")
      end

      it "stores extracted content and metadata on the archive" do
        archiver.call
        archive.reload

        expect(archive.content_html).to eq(parsed_content.content_html)
        expect(archive.content_text).to eq(parsed_content.content_text)
        expect(archive.title).to eq(parsed_content.title)
        expect(archive.description).to eq(parsed_content.description)
        expect(archive.image_url).to eq(parsed_content.image_url)
        expect(archive.metadata).to eq(parsed_content.metadata.to_h.deep_stringify_keys)
        expect(archive.fetched_at).to be_present
      end

      it "returns a success result with the archive" do
        result = archiver.call

        expect(result).to be_success
        expect(result.data).to eq(archive)
      end

      it "invokes HttpFetcher and ContentExtractor with expected arguments" do
        archiver.call

        expect(LinkRadar::ContentArchiving::HttpFetcher).to have_received(:new).with(link.url)
        expect(LinkRadar::ContentArchiving::ContentExtractor).to have_received(:new)
          .with(html: fetched_content.body, url: fetched_content.final_url)
      end
    end

    context "with successful binary content archival" do
      let(:fetched_content) do
        LinkRadar::ContentArchiving::FetchedContent.new(
          body: "%PDF...",
          status: 200,
          final_url: "https://example.com/file.pdf",
          content_type: "application/pdf"
        )
      end
      let(:fetcher) do
        instance_double(
          LinkRadar::ContentArchiving::HttpFetcher,
          call: LinkRadar::Result.success(fetched_content)
        )
      end

      before do
        allow(LinkRadar::ContentArchiving::HttpFetcher)
          .to receive(:new).with(link.url).and_return(fetcher)
        allow(LinkRadar::ContentArchiving::ContentExtractor).to receive(:new)
      end

      it "transitions to completed without invoking ContentExtractor" do
        archiver.call

        expect(LinkRadar::ContentArchiving::ContentExtractor).not_to have_received(:new)
        expect(archive.reload.current_state).to eq("completed")
      end

      it "stores metadata only and leaves content fields empty" do
        archiver.call
        archive.reload

        expect(archive.metadata).to eq(
          "content_type" => fetched_content.content_type,
          "final_url" => fetched_content.final_url
        )
        expect(archive.content_html).to be_nil
        expect(archive.content_text).to be_nil
      end
    end

    context "when HttpFetcher returns failure" do
      context "with error_code :invalid_url" do
        let(:fetch_error) do
          LinkRadar::ContentArchiving::FetchError.new(
            error_code: :invalid_url,
            error_message: "Invalid URL format",
            url: link.url,
            details: {}
          )
        end

        before do
          fetcher = instance_double(
            LinkRadar::ContentArchiving::HttpFetcher,
            call: LinkRadar::Result.failure(fetch_error.error_message, fetch_error)
          )
          allow(LinkRadar::ContentArchiving::HttpFetcher)
            .to receive(:new).with(link.url).and_return(fetcher)
        end

        it "transitions archive to failed and stores structured error metadata" do
          result = archiver.call

          expect(result).to be_failure
          expect(result.data).to eq(fetch_error)
          expect(result.errors).to include(fetch_error.error_message)

          archive.reload
          expect(archive.current_state).to eq("failed")
          expect(archive.error_message).to eq(fetch_error.error_message)

          metadata = archive.content_archive_transitions.order(:sort_key).last.metadata
          expect(metadata["error_reason"]).to eq("invalid_url")
          expect(metadata["http_status"]).to be_nil
        end
      end

      context "with error_code :blocked" do
        let(:fetch_error) do
          LinkRadar::ContentArchiving::FetchError.new(
            error_code: :blocked,
            error_message: "URL resolves to private IP address",
            url: link.url,
            details: {hostname: "127.0.0.1"}
          )
        end

        before do
          fetcher = instance_double(
            LinkRadar::ContentArchiving::HttpFetcher,
            call: LinkRadar::Result.failure(fetch_error.error_message, fetch_error)
          )
          allow(LinkRadar::ContentArchiving::HttpFetcher)
            .to receive(:new).with(link.url).and_return(fetcher)
        end

        it "stores blocked error metadata" do
          result = archiver.call

          expect(result).to be_failure
          expect(result.data).to eq(fetch_error)
          expect(result.errors).to include(fetch_error.error_message)

          archive.reload
          expect(archive.current_state).to eq("failed")
          expect(archive.error_message).to eq(fetch_error.error_message)

          metadata = archive.content_archive_transitions.order(:sort_key).last.metadata
          expect(metadata["error_reason"]).to eq("blocked")
          expect(metadata["http_status"]).to be_nil
        end
      end

      context "with error_code :network_error" do
        let(:fetch_error) do
          LinkRadar::ContentArchiving::FetchError.new(
            error_code: :network_error,
            error_message: "HTTP 404: Not Found",
            url: link.url,
            http_status: 404,
            details: {}
          )
        end

        before do
          fetcher = instance_double(
            LinkRadar::ContentArchiving::HttpFetcher,
            call: LinkRadar::Result.failure(fetch_error.error_message, fetch_error)
          )
          allow(LinkRadar::ContentArchiving::HttpFetcher)
            .to receive(:new).with(link.url).and_return(fetcher)
        end

        it "stores network error metadata including http_status" do
          result = archiver.call

          expect(result).to be_failure
          expect(result.data).to eq(fetch_error)
          expect(result.errors).to include(fetch_error.error_message)

          archive.reload
          expect(archive.current_state).to eq("failed")
          expect(archive.error_message).to eq(fetch_error.error_message)

          metadata = archive.content_archive_transitions.order(:sort_key).last.metadata
          expect(metadata["error_reason"]).to eq("network_error")
          expect(metadata["http_status"]).to eq(404)
        end
      end

      context "with error_code :size_limit" do
        let(:fetch_error) do
          LinkRadar::ContentArchiving::FetchError.new(
            error_code: :size_limit,
            error_message: "Content size exceeds limit",
            url: link.url,
            details: {max_size: 10.megabytes}
          )
        end

        before do
          fetcher = instance_double(
            LinkRadar::ContentArchiving::HttpFetcher,
            call: LinkRadar::Result.failure(fetch_error.error_message, fetch_error)
          )
          allow(LinkRadar::ContentArchiving::HttpFetcher)
            .to receive(:new).with(link.url).and_return(fetcher)
        end

        it "stores size limit error metadata" do
          result = archiver.call

          expect(result).to be_failure
          expect(result.data).to eq(fetch_error)
          expect(result.errors).to include(fetch_error.error_message)

          archive.reload
          expect(archive.current_state).to eq("failed")
          expect(archive.error_message).to eq(fetch_error.error_message)

          metadata = archive.content_archive_transitions.order(:sort_key).last.metadata
          expect(metadata["error_reason"]).to eq("size_limit")
        end
      end
    end

    context "when ContentExtractor returns failure" do
      let(:fetched_content) do
        LinkRadar::ContentArchiving::FetchedContent.new(
          body: "<html></html>",
          status: 200,
          final_url: "https://example.com/article",
          content_type: "text/html"
        )
      end
      let(:extraction_error) do
        LinkRadar::ContentArchiving::ExtractionError.new(
          error_code: :extraction_error,
          error_message: "Failed to extract content",
          url: fetched_content.final_url,
          details: {}
        )
      end
      let(:fetcher) do
        instance_double(
          LinkRadar::ContentArchiving::HttpFetcher,
          call: LinkRadar::Result.success(fetched_content)
        )
      end
      let(:extractor) do
        instance_double(
          LinkRadar::ContentArchiving::ContentExtractor,
          call: LinkRadar::Result.failure(extraction_error.error_message, extraction_error)
        )
      end

      before do
        allow(LinkRadar::ContentArchiving::HttpFetcher)
          .to receive(:new).with(link.url).and_return(fetcher)

        allow(LinkRadar::ContentArchiving::ContentExtractor)
          .to receive(:new)
          .with(html: fetched_content.body, url: fetched_content.final_url)
          .and_return(extractor)
      end

      it "transitions archive to failed with error_reason='extraction_error'" do
        result = archiver.call

        expect(result).to be_failure
        expect(result.data).to eq(extraction_error)
        expect(result.errors).to include(extraction_error.error_message)

        archive.reload
        expect(archive.current_state).to eq("failed")
        expect(archive.error_message).to eq(extraction_error.error_message)

        metadata = archive.content_archive_transitions.order(:sort_key).last.metadata
        expect(metadata["error_reason"]).to eq("extraction_error")
      end
    end

    context "when archival is disabled" do
      let(:config) { instance_double(ContentArchiveConfig, enabled: false) }

      it "fails without invoking HttpFetcher or ContentExtractor" do
        expect(LinkRadar::ContentArchiving::HttpFetcher).not_to receive(:new)
        expect(LinkRadar::ContentArchiving::ContentExtractor).not_to receive(:new)

        result = archiver.call

        expect(result).to be_failure
        expect(result.errors).to include("Content archival disabled")

        archive.reload
        expect(archive.current_state).to eq("failed")
        expect(archive.error_message).to eq("Content archival disabled")
        metadata = archive.content_archive_transitions.order(:sort_key).last.metadata
        expect(metadata["error_reason"]).to eq("disabled")
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(LinkRadar::ContentArchiving::HttpFetcher)
          .to receive(:new).and_raise(StandardError, "boom")
        allow(Rails.logger).to receive(:error)
      end

      it "transitions archive to failed and logs the error" do
        result = archiver.call

        expect(result).to be_failure
        expect(result.errors.first).to include("Unexpected error")

        archive.reload
        expect(archive.current_state).to eq("failed")
        expect(archive.error_message).to include("Unexpected error: StandardError - boom")

        expect(Rails.logger).to have_received(:error).with(/ContentArchive #{archive.id} error/).once
        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end
  end
end
