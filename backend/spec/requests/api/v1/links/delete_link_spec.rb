# frozen_string_literal: true

require "rails_helper"

describe "API: Delete a Link" do
  let(:link) { create(:link) }

  context "when unauthenticated" do
    it_behaves_like "authentication required", :delete, "/api/v1/links/#{SecureRandom.uuid}"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful deletion" do
      before do
        delete "/api/v1/links/#{link.id}"
      end

      it "returns status :no_content" do
        expect(response).to have_http_status(:no_content)
      end

      it "returns empty body" do
        expect(response.body).to be_empty
      end

      it "actually deletes the link from database" do
        expect(Link.find_by(id: link.id)).to be_nil
      end
    end

    describe "deleting link with tags" do
      let(:tag1) { create(:tag, name: "tag-1") }
      let(:tag2) { create(:tag, name: "tag-2") }
      let(:link_with_tags) { create(:link, tags: [tag1, tag2]) }

      before do
        delete "/api/v1/links/#{link_with_tags.id}"
      end

      it "deletes the link" do
        expect(response).to have_http_status(:no_content)
        expect(Link.find_by(id: link_with_tags.id)).to be_nil
      end

      it "does not delete the tags" do
        expect(Tag.find_by(id: tag1.id)).to be_present
        expect(Tag.find_by(id: tag2.id)).to be_present
      end

      it "removes the associations" do
        expect(LinkTag.where(link_id: link_with_tags.id)).to be_empty
      end
    end

    describe "non-existent link" do
      let(:non_existent_id) { SecureRandom.uuid }

      before do
        delete "/api/v1/links/#{non_existent_id}"
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
        delete "/api/v1/links/invalid-id"
      end

      it "returns status :not_found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "idempotency" do
      before do
        # Delete once
        delete "/api/v1/links/#{link.id}"
        # Try to delete again
        delete "/api/v1/links/#{link.id}"
      end

      it "returns not_found on second deletion" do
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "verifying complete removal" do
      let(:link_id) { link.id }

      it "removes the link from all queries" do
        delete "/api/v1/links/#{link_id}"

        expect(Link.all).not_to include(link)
        expect(Link.count).to eq(0)
        expect { Link.find(link_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
