# frozen_string_literal: true

require "rails_helper"

describe "API: Fetch Link by URL" do
  context "when unauthenticated" do
    it_behaves_like "authentication required", :get, "/api/v1/links/by_url"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful retrieval" do
      let(:link) { create(:link, url: "https://example.com/test-page") }

      before do
        link # Ensure link exists
        get "/api/v1/links/by_url", params: {url: link.url}
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the matching link" do
        expect(json_response.dig(:data, :link, :id)).to eq(link.id)
        expect(json_response.dig(:data, :link, :url)).to eq(link.url)
      end

      it "includes link details" do
        expect(json_response.dig(:data, :link, :note)).to eq(link.note)
        expect(json_response.dig(:data, :link, :tags)).to be_an(Array)
      end
    end

    describe "exact URL matching" do
      let!(:link1) { create(:link, url: "https://example.com") }
      let!(:link2) { create(:link, url: "https://example.com/page") }

      before do
        get "/api/v1/links/by_url", params: {url: "https://example.com"}
      end

      it "returns only exact match" do
        expect(json_response.dig(:data, :link, :id)).to eq(link1.id)
      end

      it "does not return similar URLs" do
        expect(json_response.dig(:data, :link, :id)).not_to eq(link2.id)
      end
    end

    describe "link with tags" do
      let(:tag1) { create(:tag, name: "documentation") }
      let(:tag2) { create(:tag, name: "reference") }
      let(:link_with_tags) { create(:link, tags: [tag1, tag2]) }

      before do
        get "/api/v1/links/by_url", params: {url: link_with_tags.url}
      end

      it "includes associated tags" do
        tags = json_response.dig(:data, :link, :tags)
        expect(tags.size).to eq(2)
        tag_names = tags.pluck(:name)
        expect(tag_names).to contain_exactly("documentation", "reference")
      end
    end

    describe "missing URL parameter" do
      before do
        get "/api/v1/links/by_url"
      end

      it "returns status :bad_request" do
        expect(response).to have_http_status(:bad_request)
      end

      it "returns structured error response" do
        expect(json_response).to have_key(:error)
        expect(json_response[:error]).to have_key(:code)
        expect(json_response[:error]).to have_key(:message)
        expect(json_response[:error][:code]).to eq("invalid_argument")
        expect(json_response[:error][:message]).to eq("URL parameter is required")
      end
    end

    describe "empty URL parameter" do
      before do
        get "/api/v1/links/by_url", params: {url: ""}
      end

      it "returns status :bad_request" do
        expect(response).to have_http_status(:bad_request)
      end

      it "returns error message" do
        expect(json_response[:error][:message]).to eq("URL parameter is required")
      end
    end

    describe "non-existent URL" do
      before do
        get "/api/v1/links/by_url", params: {url: "https://nonexistent.example.com"}
      end

      it "returns status :not_found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns structured error response" do
        expect(json_response).to have_key(:error)
        expect(json_response[:error]).to have_key(:code)
        expect(json_response[:error]).to have_key(:message)
        expect(json_response[:error][:code]).to eq("record_not_found")
      end
    end

    describe "URL with special characters" do
      let(:encoded_url) { "https://example.com/path?query=value&other=data" }
      let!(:link) { create(:link, url: encoded_url) }

      before do
        get "/api/v1/links/by_url", params: {url: encoded_url}
      end

      it "finds the link" do
        expect(response).to have_http_status(:ok)
        expect(json_response.dig(:data, :link, :id)).to eq(link.id)
      end
    end
  end
end
