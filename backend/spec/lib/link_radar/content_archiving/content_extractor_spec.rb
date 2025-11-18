# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::ContentArchiving::ContentExtractor do
  describe "#call" do
    let(:url) { "https://example.com/article" }
    let(:html) do
      <<~HTML
        <html>
          <head>
            <title>Example Title</title>
          </head>
          <body>
            <div id="content">
              <p>Example content</p>
            </div>
          </body>
        </html>
      HTML
    end

    context "with well-formed HTML" do
      let(:metainspector) { instance_double(MetaInspector::Document) }
      let(:images) { instance_double("MetaInspectorImages", best: "https://example.com/og-image.jpg") }
      let(:meta_tags) do
        {
          "og:title" => ["OG Title"],
          "og:description" => ["OG Description"],
          "og:image" => ["https://example.com/og-image.jpg"],
          "twitter:card" => ["summary"],
          "twitter:title" => ["Twitter Title"],
          "twitter:description" => ["Twitter Description"],
          "twitter:image" => ["https://example.com/twitter-image.jpg"],
          "canonical" => ["https://example.com/canonical"]
        }
      end
      let(:readability_html) { %(<div onclick="alert(1)"><p>Safe content</p><script>alert()</script></div>) }
      let(:readability_document) { instance_double(Readability::Document, content: readability_html) }
      let(:loofah_fragment) { double("LoofahFragment") }
      let(:sanitized_html) { "<div><p>Safe content</p></div>" }

      before do
        allow(MetaInspector).to receive(:new).with(url, document: html, warn_level: :store).and_return(metainspector)
        allow(metainspector).to receive(:best_title).and_return("OG Title")
        allow(metainspector).to receive(:title).and_return("Example Title")
        allow(metainspector).to receive(:best_description).and_return("Best description")
        allow(metainspector).to receive(:description).and_return("Fallback description")
        allow(metainspector).to receive(:images).and_return(images)
        allow(metainspector).to receive(:meta_tags).and_return(meta_tags)

        allow(Readability::Document).to receive(:new).with(html, tags: %w[div p article section]).and_return(readability_document)

        allow(Loofah).to receive(:fragment).with(readability_html).and_return(loofah_fragment)
        allow(loofah_fragment).to receive(:scrub!).with(:prune).and_return(loofah_fragment)
        allow(loofah_fragment).to receive(:to_s).and_return(sanitized_html)
      end

      it "returns success with ParsedContent containing sanitized HTML" do
        result = described_class.new(html: html, url: url).call

        expect(result).to be_success
        expect(result.data).to be_a(LinkRadar::ContentArchiving::ParsedContent)
        expect(result.data.content_html).to eq(sanitized_html)
        expect(result.data.content_text).to include("Safe content")
      end

      it "extracts metadata and populates fields" do
        result = described_class.new(html: html, url: url).call
        parsed = result.data

        expect(parsed.title).to eq("OG Title")
        expect(parsed.description).to eq("Best description")
        expect(parsed.image_url).to eq("https://example.com/og-image.jpg")

        expect(parsed.metadata).to be_a(LinkRadar::ContentArchiving::ContentMetadata)
        expect(parsed.metadata.final_url).to eq(url)
        expect(parsed.metadata.content_type).to eq("html")
        expect(parsed.metadata.canonical_url).to eq("https://example.com/canonical")
        expect(parsed.metadata.opengraph).to eq(
          "title" => "OG Title",
          "description" => "OG Description",
          "image" => "https://example.com/og-image.jpg"
        )
        expect(parsed.metadata.twitter).to eq(
          "card" => "summary",
          "title" => "Twitter Title",
          "description" => "Twitter Description",
          "image" => "https://example.com/twitter-image.jpg"
        )
      end

      it "sanitizes HTML to remove scripts and event handlers" do
        result = described_class.new(html: html, url: url).call

        expect(result.data.content_html).to eq("<div><p>Safe content</p></div>")
        expect(Loofah).to have_received(:fragment).with(readability_html)
      end
    end

    context "when metadata extraction fails" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("metadata boom"))
      end

      it "returns failure with extraction error" do
        result = described_class.new(html: html, url: url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Metadata extraction error: metadata boom")
        expect(result.data).to be_a(LinkRadar::ContentArchiving::ExtractionError)
        expect(result.data.error_code).to eq(:extraction_error)
      end
    end

    context "when content extraction fails" do
      let(:metainspector) { instance_double(MetaInspector::Document, best_title: nil, title: "Example Title", best_description: nil, description: nil, images: instance_double("Images", best: nil), meta_tags: {}) }

      before do
        allow(MetaInspector).to receive(:new).and_return(metainspector)
        allow(Readability::Document).to receive(:new).and_raise(StandardError.new("readability boom"))
      end

      it "returns failure with extraction error" do
        result = described_class.new(html: html, url: url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Content extraction error: readability boom")
        expect(result.data.error_code).to eq(:extraction_error)
      end
    end

    context "when sanitization fails" do
      let(:metainspector) { instance_double(MetaInspector::Document, best_title: nil, title: "Example Title", best_description: nil, description: nil, images: instance_double("Images", best: nil), meta_tags: {}) }
      let(:readability_document) { instance_double(Readability::Document, content: "<div>content</div>") }

      before do
        allow(MetaInspector).to receive(:new).and_return(metainspector)
        allow(Readability::Document).to receive(:new).and_return(readability_document)
        allow(Loofah).to receive(:fragment).and_raise(StandardError.new("sanitize boom"))
      end

      it "returns failure with extraction error" do
        result = described_class.new(html: html, url: url).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("HTML sanitization error: sanitize boom")
        expect(result.data.error_code).to eq(:extraction_error)
      end
    end
  end
end
