# frozen_string_literal: true

require "rails_helper"

describe "API: Download Snapshot" do
  # Use temporary directory for test exports
  let(:temp_export_dir) { Rails.root.join("tmp/test_exports") }

  before do
    stub_const("LinkRadar::DataExport::Exporter::EXPORT_DIR", temp_export_dir)
    FileUtils.rm_rf(temp_export_dir)
    FileUtils.mkdir_p(temp_export_dir)
  end

  after do
    FileUtils.rm_rf(temp_export_dir) if temp_export_dir.exist?
  end

  let(:filename) { "linkradar-export-2025-11-14-143022-#{SecureRandom.uuid}.json" }
  let(:file_path) { temp_export_dir.join(filename) }

  context "when unauthenticated" do
    it_behaves_like "authentication required", :get, "/api/v1/snapshot/exports/test-file.json"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful download" do
      let(:export_data) do
        {
          version: "1.0",
          exported_at: Time.current.utc.iso8601,
          metadata: {link_count: 1, tag_count: 1},
          links: [
            {
              url: "https://example.com/",
              note: "Test link",
              created_at: Time.current.utc.iso8601,
              tags: [{name: "ruby", description: nil}]
            }
          ]
        }
      end

      before do
        # Create a test export file
        File.write(file_path, JSON.pretty_generate(export_data))
      end

      it "returns status :ok" do
        get "/api/v1/snapshot/exports/#{filename}"
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON content type" do
        get "/api/v1/snapshot/exports/#{filename}"
        expect(response.content_type).to include("application/json")
      end

      it "sets content-disposition to attachment" do
        get "/api/v1/snapshot/exports/#{filename}"
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(filename)
      end

      it "returns the export file contents" do
        get "/api/v1/snapshot/exports/#{filename}"
        parsed = JSON.parse(response.body)

        expect(parsed["version"]).to eq("1.0")
        expect(parsed["metadata"]["link_count"]).to eq(1)
        expect(parsed["links"].size).to eq(1)
      end
    end

    describe "file not found" do
      let(:nonexistent_file) { "linkradar-export-nonexistent-#{SecureRandom.uuid}.json" }

      before do
        get "/api/v1/snapshot/exports/#{nonexistent_file}"
      end

      it "returns status :not_found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns structured error response" do
        expect(json_response).to have_key(:error)
        expect(json_response[:error]).to have_key(:code)
        expect(json_response[:error]).to have_key(:message)
        expect(json_response[:error][:code]).to eq("not_found")
      end
    end

    describe "path traversal protection" do
      # Note: Rails routing already blocks most path traversal attempts,
      # but the controller has additional checks

      context "with relative path attempts" do
        let(:malicious_filename) { "../../../etc/passwd" }

        it "returns not_found (routing blocks it)" do
          # Rails routing will reject this before it reaches the controller
          get "/api/v1/snapshot/exports/#{malicious_filename}"
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe "filename constraints" do
      context "with filename without .json extension" do
        let(:filename_without_ext) { "linkradar-export-2025-11-14-143022-#{SecureRandom.uuid}" }

        before do
          # Create file without .json extension
          file_without_ext = temp_export_dir.join(filename_without_ext)
          File.write(file_without_ext, JSON.generate({test: "data"}))

          get "/api/v1/snapshot/exports/#{filename_without_ext}"
        end

        it "serves the file successfully" do
          # Our route constraint allows any filename pattern
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
