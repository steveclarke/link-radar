# frozen_string_literal: true

require "rails_helper"

describe "API: Import Snapshot" do
  context "when unauthenticated" do
    it_behaves_like "authentication required", :post, "/api/v1/snapshot/import"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    # Helper to create valid import JSON file
    def create_import_file(links_data)
      json_data = {
        version: "1.0",
        exported_at: Time.current.utc.iso8601,
        metadata: {
          link_count: links_data.size,
          tag_count: links_data.flat_map { |l| l[:tags] }.uniq.size
        },
        links: links_data
      }

      file = Tempfile.new(["import", ".json"])
      file.write(JSON.pretty_generate(json_data))
      file.rewind
      file
    end

    describe "successful import" do
      let(:import_data) do
        [
          {
            url: "https://example.com",
            note: "Example site",
            created_at: 1.day.ago.utc.iso8601,
            tags: [{name: "ruby", description: "Ruby language"}]
          },
          {
            url: "https://rails.org",
            note: "Rails framework",
            created_at: 2.days.ago.utc.iso8601,
            tags: [{name: "rails", description: nil}]
          }
        ]
      end

      context "with skip mode (default)" do
        it "imports links successfully" do
          file = create_import_file(import_data)

          post "/api/v1/snapshot/import", params: {file: Rack::Test::UploadedFile.new(file.path, "application/json")}

          expect(response).to have_http_status(:ok)
          expect(json_response).to have_key(:data)
          expect(json_response[:data][:links_imported]).to eq(2)
          expect(json_response[:data][:links_skipped]).to eq(0)
          expect(json_response[:data][:tags_created]).to eq(2)

          file.close
          file.unlink
        end

        it "returns import statistics" do
          file = create_import_file(import_data)

          post "/api/v1/snapshot/import", params: {file: Rack::Test::UploadedFile.new(file.path, "application/json")}

          expect(json_response[:data]).to have_key(:links_imported)
          expect(json_response[:data]).to have_key(:links_skipped)
          expect(json_response[:data]).to have_key(:tags_created)
          expect(json_response[:data]).to have_key(:tags_reused)

          file.close
          file.unlink
        end
      end

      context "with update mode" do
        it "imports with update mode when specified" do
          file = create_import_file(import_data)

          post "/api/v1/snapshot/import", params: {
            file: Rack::Test::UploadedFile.new(file.path, "application/json"),
            mode: "update"
          }

          expect(response).to have_http_status(:ok)
          expect(json_response[:data][:links_imported]).to eq(2)

          file.close
          file.unlink
        end
      end
    end

    describe "duplicate URL handling" do
      let!(:existing_link) do
        create(:link, url: "https://example.com", note: "Original").tap do |link|
          link.tag_names = ["original"]
          link.save!
        end
      end

      let(:import_data) do
        [
          {
            url: "https://example.com",
            note: "Updated note",
            created_at: 1.day.ago.utc.iso8601,
            tags: [{name: "imported", description: nil}]
          }
        ]
      end

      context "with skip mode" do
        it "skips duplicate URLs" do
          file = create_import_file(import_data)

          post "/api/v1/snapshot/import", params: {
            file: Rack::Test::UploadedFile.new(file.path, "application/json"),
            mode: "skip"
          }

          expect(response).to have_http_status(:ok)
          expect(json_response[:data][:links_imported]).to eq(0)
          expect(json_response[:data][:links_skipped]).to eq(1)

          # Verify existing link unchanged
          existing_link.reload
          expect(existing_link.note).to eq("Original")

          file.close
          file.unlink
        end
      end

      context "with update mode" do
        it "updates duplicate URLs" do
          file = create_import_file(import_data)

          post "/api/v1/snapshot/import", params: {
            file: Rack::Test::UploadedFile.new(file.path, "application/json"),
            mode: "update"
          }

          expect(response).to have_http_status(:ok)
          expect(json_response[:data][:links_imported]).to eq(1)
          expect(json_response[:data][:links_skipped]).to eq(0)

          # Verify link was updated
          existing_link.reload
          expect(existing_link.note).to eq("Updated note")

          file.close
          file.unlink
        end
      end
    end

    describe "error handling" do
      context "with missing file parameter" do
        it "returns bad request status" do
          post "/api/v1/snapshot/import"

          expect(response).to have_http_status(:bad_request)
        end

        it "returns structured error response" do
          post "/api/v1/snapshot/import"

          expect(json_response).to have_key(:error)
          expect(json_response[:error][:code]).to eq("no_file_provided")
          expect(json_response[:error][:message]).to eq("No file provided")
        end
      end

      context "with invalid JSON" do
        it "returns unprocessable entity status" do
          file = Tempfile.new(["import", ".json"])
          file.write("{ invalid json")
          file.rewind

          post "/api/v1/snapshot/import", params: {file: Rack::Test::UploadedFile.new(file.path, "application/json")}

          expect(response).to have_http_status(:unprocessable_content)

          file.close
          file.unlink
        end
      end

      context "with unsupported version" do
        it "returns unprocessable entity status" do
          invalid_data = {
            version: "2.0",
            exported_at: Time.current.utc.iso8601,
            metadata: {link_count: 0, tag_count: 0},
            links: []
          }

          file = Tempfile.new(["import", ".json"])
          file.write(JSON.pretty_generate(invalid_data))
          file.rewind

          post "/api/v1/snapshot/import", params: {file: Rack::Test::UploadedFile.new(file.path, "application/json")}

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response[:error][:message]).to include("Unsupported version")

          file.close
          file.unlink
        end
      end
    end
  end
end
