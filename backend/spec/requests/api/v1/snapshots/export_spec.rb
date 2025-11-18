# frozen_string_literal: true

require "rails_helper"

describe "API: Export Snapshot" do
  # Use temporary directory for test exports
  let(:temp_export_dir) { Rails.root.join("tmp/test_exports") }

  before do
    stub_const("LinkRadar::Snapshot::Exporter::EXPORT_DIR", temp_export_dir)
    FileUtils.rm_rf(temp_export_dir)
    FileUtils.mkdir_p(temp_export_dir)
  end

  after do
    FileUtils.rm_rf(temp_export_dir) if temp_export_dir.exist?
  end

  context "when unauthenticated" do
    it_behaves_like "authentication required", :post, "/api/v1/snapshot/export"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful export" do
      let!(:link1) do
        create(:link, url: "https://example.com", note: "Example").tap do |link|
          link.tag_names = ["ruby", "web"]
          link.save!
        end
      end

      let!(:link2) do
        create(:link, url: "https://rails.org", note: "Rails").tap do |link|
          link.tag_names = ["ruby", "rails"]
          link.save!
        end
      end

      before do
        post "/api/v1/snapshot/export"
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns export metadata" do
        expect(json_response.dig(:data, :file_path)).to be_present
        expect(json_response.dig(:data, :link_count)).to eq(2)
        expect(json_response.dig(:data, :tag_count)).to eq(3)
      end

      it "returns download URL" do
        download_url = json_response.dig(:data, :download_url)
        expect(download_url).to start_with("/api/v1/snapshot/exports/")
        expect(download_url).to end_with(".json")
      end

      it "creates export file on disk" do
        filename = json_response.dig(:data, :file_path)
        file_path = temp_export_dir.join(filename)
        expect(File.exist?(file_path)).to be true
      end

      it "creates valid JSON export" do
        filename = json_response.dig(:data, :file_path)
        file_content = File.read(temp_export_dir.join(filename))
        json = JSON.parse(file_content)

        expect(json["version"]).to eq("1.0")
        expect(json["links"].size).to eq(2)
      end
    end

    describe "with ~temp~ tagged links" do
      let!(:regular_link) do
        create(:link, url: "https://example.com").tap do |link|
          link.tag_names = ["ruby"]
          link.save!
        end
      end

      let!(:temp_link) do
        create(:link, url: "https://temp.com").tap do |link|
          link.tag_names = ["~temp~"]
          link.save!
        end
      end

      before do
        post "/api/v1/snapshot/export"
      end

      it "excludes ~temp~ tagged links from count" do
        expect(json_response.dig(:data, :link_count)).to eq(1)
      end

      it "excludes ~temp~ tagged links from file" do
        filename = json_response.dig(:data, :file_path)
        file_content = File.read(temp_export_dir.join(filename))
        json = JSON.parse(file_content)
        urls = json["links"].pluck("url")

        expect(urls).not_to include("https://temp.com/")
      end
    end

    describe "with empty database" do
      before do
        post "/api/v1/snapshot/export"
      end

      it "successfully exports with zero links" do
        expect(response).to have_http_status(:ok)
        expect(json_response.dig(:data, :link_count)).to eq(0)
        expect(json_response.dig(:data, :tag_count)).to eq(0)
      end

      it "creates valid empty export file" do
        filename = json_response.dig(:data, :file_path)
        file_content = File.read(temp_export_dir.join(filename))
        json = JSON.parse(file_content)

        expect(json["links"]).to eq([])
      end
    end

    describe "export error handling" do
      before do
        # Make directory read-only to trigger write failure
        FileUtils.chmod(0o444, temp_export_dir)
      end

      after do
        # Restore permissions for cleanup
        FileUtils.chmod(0o755, temp_export_dir) if File.exist?(temp_export_dir)
      end

      it "returns status :internal_server_error" do
        post "/api/v1/snapshot/export"
        expect(response).to have_http_status(:internal_server_error)
      end

      it "returns structured error response" do
        post "/api/v1/snapshot/export"

        expect(json_response).to have_key(:error)
        expect(json_response[:error]).to have_key(:code)
        expect(json_response[:error]).to have_key(:message)
        expect(json_response[:error][:code]).to eq("export_failed")
      end
    end
  end
end
