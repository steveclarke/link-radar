# frozen_string_literal: true

require "rails_helper"

describe "API: Fetch One Link" do
  let(:link) { create(:link) }

  context "when unauthenticated" do
    it_behaves_like "authentication required", :get, "/api/v1/links/#{SecureRandom.uuid}"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful retrieval" do
      before do
        get "/api/v1/links/#{link.id}"
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the link data" do
        expect(json_response.dig(:data, :link, :id)).to eq(link.id)
        expect(json_response.dig(:data, :link, :url)).to eq(link.url)
        expect(json_response.dig(:data, :link, :note)).to eq(link.note)
      end

      it "includes tags array" do
        expect(json_response.dig(:data, :link, :tags)).to be_an(Array)
      end

      it "uses proper JSON structure" do
        expect(json_response).to have_key(:data)
        expect(json_response[:data]).to have_key(:link)
      end
    end

    describe "link with tags" do
      let(:tag1) { create(:tag, name: "ruby") }
      let(:tag2) { create(:tag, name: "tutorial") }
      let(:link_with_tags) { create(:link, tags: [tag1, tag2]) }

      before do
        get "/api/v1/links/#{link_with_tags.id}"
      end

      it "includes all associated tags" do
        tags = json_response.dig(:data, :link, :tags)
        expect(tags.size).to eq(2)
      end

      it "includes tag details" do
        tag = json_response.dig(:data, :link, :tags).first
        expect(tag).to have_key(:id)
        expect(tag).to have_key(:name)
        expect(tag).to have_key(:slug)
      end

      it "includes correct tag names" do
        tag_names = json_response.dig(:data, :link, :tags).pluck(:name)
        expect(tag_names).to contain_exactly("ruby", "tutorial")
      end
    end

    describe "non-existent link" do
      let(:non_existent_id) { SecureRandom.uuid }

      before do
        get "/api/v1/links/#{non_existent_id}"
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

    describe "invalid UUID format" do
      before do
        get "/api/v1/links/invalid-id"
      end

      it "returns status :not_found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
