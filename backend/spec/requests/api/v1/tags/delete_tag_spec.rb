# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API: Delete a Tag", type: :request do
  describe "DELETE /api/v1/tags/:id" do
    describe "when authenticated" do
      include_context "with authenticated request"
      let!(:tag) { create(:tag, name: "Ruby") }

      describe "successful deletion" do
        before do
          delete "/api/v1/tags/#{tag.id}"
        end

        it "returns status :no_content" do
          expect(response).to have_http_status(:no_content)
        end

        it "returns empty body" do
          expect(response.body).to be_empty
        end

        it "removes the tag from database" do
          expect(Tag.find_by(id: tag.id)).to be_nil
        end
      end

      describe "deleting tag with associated links" do
        let!(:links) { create_list(:link, 3) }

        before do
          links.each { |link| link.tags << tag }
          delete "/api/v1/tags/#{tag.id}"
        end

        it "successfully deletes the tag" do
          expect(response).to have_http_status(:no_content)
          expect(Tag.find_by(id: tag.id)).to be_nil
        end

        it "removes the tag associations (link_tags)" do
          expect(LinkTag.where(tag_id: tag.id)).to be_empty
        end

        it "does not delete the associated links" do
          links.each do |link|
            expect(Link.find_by(id: link.id)).to be_present
          end
        end

        it "removes tag from links' tag collections" do
          links.each do |link|
            link.reload
            expect(link.tags).not_to include(tag)
          end
        end
      end

      describe "error cases" do
        context "with non-existent tag ID" do
          before do
            delete "/api/v1/tags/#{SecureRandom.uuid}"
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
            delete "/api/v1/tags/invalid-id"
          end

          it "returns status :not_found" do
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      describe "idempotency" do
        it "second deletion returns 404" do
          delete "/api/v1/tags/#{tag.id}"
          expect(response).to have_http_status(:no_content)

          delete "/api/v1/tags/#{tag.id}"
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe "when not authenticated" do
      let!(:tag) { create(:tag) }

      it "returns 401 Unauthorized" do
        delete "/api/v1/tags/#{tag.id}"
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not delete the tag" do
        delete "/api/v1/tags/#{tag.id}"
        expect(Tag.find_by(id: tag.id)).to be_present
      end
    end
  end
end
