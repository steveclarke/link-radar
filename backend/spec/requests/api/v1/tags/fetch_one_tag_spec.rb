# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API: Fetch One Tag", type: :request do
  describe "GET /api/v1/tags/:id" do
    describe "when authenticated" do
      include_context "with authenticated request"
      let!(:tag) { create(:tag, name: "Ruby", description: "A programming language") }

      describe "successful retrieval" do
        before do
          get "/api/v1/tags/#{tag.id}"
        end

        it "returns status :ok" do
          expect(response).to have_http_status(:ok)
        end

        it "returns the tag data" do
          expect(json_response.dig(:data, :tag, :id)).to eq(tag.id)
          expect(json_response.dig(:data, :tag, :name)).to eq("Ruby")
          expect(json_response.dig(:data, :tag, :description)).to eq("A programming language")
        end

        it "includes all tag attributes" do
          tag_data = json_response.dig(:data, :tag)
          expect(tag_data).to have_key(:id)
          expect(tag_data).to have_key(:name)
          expect(tag_data).to have_key(:slug)
          expect(tag_data).to have_key(:description)
          expect(tag_data).to have_key(:usage_count)
          expect(tag_data).to have_key(:last_used_at)
          expect(tag_data).to have_key(:created_at)
          expect(tag_data).to have_key(:updated_at)
        end
      end

      describe "with recent links" do
        let!(:links) do
          12.times.map do |i|
            create(:link, url: "https://example.com/#{i}").tap do |link|
              link.tags << tag
            end
          end
        end

        before do
          get "/api/v1/tags/#{tag.id}"
        end

        it "includes up to 10 recent links" do
          recent_links = json_response.dig(:data, :recent_links)
          expect(recent_links).to be_an(Array)
          expect(recent_links.size).to eq(10)
        end

        it "orders links by created_at descending (newest first)" do
          recent_links = json_response.dig(:data, :recent_links)
          urls = recent_links.map { |l| l[:url] }

          # Most recent links should come first
          expect(urls.first).to include("/11")
          expect(urls.last).to include("/2")
        end

        it "includes link attributes" do
          link_data = json_response.dig(:data, :recent_links).first
          expect(link_data).to have_key(:id)
          expect(link_data).to have_key(:url)
          expect(link_data).to have_key(:created_at)
        end
      end

      describe "tag with no links" do
        let!(:unused_tag) { create(:tag, name: "Unused") }

        before do
          get "/api/v1/tags/#{unused_tag.id}"
        end

        it "does not include recent_links key when no links exist" do
          expect(json_response[:data]).not_to have_key(:recent_links)
        end
      end

      describe "error cases" do
        context "with non-existent tag ID" do
          before do
            get "/api/v1/tags/#{SecureRandom.uuid}"
          end

          it "returns status :not_found" do
            expect(response).to have_http_status(:not_found)
          end

          it "returns structured error response" do
            expect(json_response).to have_key(:error)
            expect(json_response[:error]).to have_key(:code)
            expect(json_response[:error][:code]).to eq("record_not_found")
          end
        end

        context "with invalid ID format" do
          before do
            get "/api/v1/tags/invalid-id"
          end

          it "returns status :not_found" do
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    describe "when not authenticated" do
      let!(:tag) { create(:tag) }

      it "returns 401 Unauthorized" do
        get "/api/v1/tags/#{tag.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
