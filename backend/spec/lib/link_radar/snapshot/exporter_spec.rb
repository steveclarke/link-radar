# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::Snapshot::Exporter do
  # Use a temporary directory for tests to avoid cluttering snapshot/exports
  let(:temp_export_dir) { Rails.root.join("tmp/test_exports") }

  before do
    # Stub the EXPORT_DIR constant to use our temp directory
    stub_const("LinkRadar::Snapshot::Exporter::EXPORT_DIR", temp_export_dir)

    # Ensure temp directory exists and is clean
    FileUtils.rm_rf(temp_export_dir)
    FileUtils.mkdir_p(temp_export_dir)
  end

  after do
    # Clean up temp directory after each test
    FileUtils.rm_rf(temp_export_dir) if temp_export_dir.exist?
  end

  describe "#call" do
    let(:exporter) { described_class.new }

    context "with links and tags" do
      let!(:link1) do
        create(:link, url: "https://example.com", note: "Example site").tap do |link|
          link.tag_names = ["ruby", "web"]
          link.save!
        end
      end

      let!(:link2) do
        create(:link, url: "https://rails.org", note: "Rails framework").tap do |link|
          link.tag_names = ["ruby", "rails"]
          link.save!
        end
      end

      it "returns success with file path and counts" do
        result = exporter.call

        expect(result).to be_success
        expect(result.data[:file_path]).to be_present
        expect(result.data[:link_count]).to eq(2)
        expect(result.data[:tag_count]).to eq(3) # ruby, web, rails
      end

      it "creates valid JSON file with correct structure" do
        result = exporter.call
        file_path = result.data[:file_path]

        expect(File.exist?(file_path)).to be true

        json = JSON.parse(File.read(file_path))

        # Verify top-level structure
        expect(json["version"]).to eq("1.0")
        expect(json["exported_at"]).to be_present
        expect(json["metadata"]["link_count"]).to eq(2)
        expect(json["metadata"]["tag_count"]).to eq(3)

        # Verify links array
        expect(json["links"]).to be_an(Array)
        expect(json["links"].size).to eq(2)

        # Verify first link structure (URLs are normalized with trailing slash)
        first_link = json["links"].first
        expect(first_link["url"]).to eq("https://example.com/")
        expect(first_link["note"]).to eq("Example site")
        expect(first_link["created_at"]).to be_present
        expect(first_link["tags"]).to be_an(Array)
        expect(first_link["tags"].pluck("name")).to match_array(["ruby", "web"])
      end

      it "generates filename with timestamp and UUID" do
        result = exporter.call
        filename = File.basename(result.data[:file_path])

        # Format: linkradar-export-YYYY-MM-DD-HHMMSS-<uuid>.json
        expect(filename).to match(/^linkradar-export-\d{4}-\d{2}-\d{2}-\d{6}-[0-9a-f-]{36}\.json$/)
      end

      it "creates pretty-printed JSON (human-readable)" do
        result = exporter.call
        file_content = File.read(result.data[:file_path])

        # Pretty-printed JSON has newlines and indentation
        expect(file_content).to include("\n")
        expect(file_content.lines.count).to be > 10
      end
    end

    context "with ~temp~ tagged links" do
      let!(:regular_link) do
        create(:link, url: "https://example.com", note: "Regular link").tap do |link|
          link.tag_names = ["ruby"]
          link.save!
        end
      end

      let!(:temp_link) do
        create(:link, url: "https://temp.com", note: "Temporary link").tap do |link|
          link.tag_names = ["~temp~"]
          link.save!
        end
      end

      it "excludes ~temp~ tagged links from export" do
        result = exporter.call

        expect(result).to be_success
        expect(result.data[:link_count]).to eq(1) # Only regular link

        json = JSON.parse(File.read(result.data[:file_path]))
        urls = json["links"].pluck("url")

        # URLs are normalized with trailing slashes
        expect(urls).to include("https://example.com/")
        expect(urls).not_to include("https://temp.com/")
      end

      it "excludes ~temp~ tag from tag count" do
        result = exporter.call

        expect(result).to be_success
        expect(result.data[:tag_count]).to eq(1) # Only 'ruby' tag counted
      end
    end

    context "with empty database" do
      it "creates valid empty export" do
        result = exporter.call

        expect(result).to be_success
        expect(result.data[:link_count]).to eq(0)
        expect(result.data[:tag_count]).to eq(0)

        json = JSON.parse(File.read(result.data[:file_path]))

        expect(json["version"]).to eq("1.0")
        expect(json["links"]).to eq([])
        expect(json["metadata"]["link_count"]).to eq(0)
        expect(json["metadata"]["tag_count"]).to eq(0)
      end
    end

    context "when export directory doesn't exist" do
      before do
        FileUtils.rm_rf(temp_export_dir)
      end

      it "creates the directory and exports successfully" do
        result = exporter.call

        expect(result).to be_success
        expect(File.directory?(temp_export_dir)).to be true
      end
    end

    context "when file write fails" do
      before do
        # Make directory read-only to trigger write failure
        FileUtils.chmod(0o444, temp_export_dir)
      end

      after do
        # Restore permissions for cleanup
        FileUtils.chmod(0o755, temp_export_dir) if File.exist?(temp_export_dir)
      end

      it "returns failure with error message" do
        result = exporter.call

        expect(result).to be_failure
        expect(result.errors).to be_present
        expect(result.errors.first).to include("Export failed")
      end
    end
  end
end
