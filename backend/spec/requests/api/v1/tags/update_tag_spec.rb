# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API: Update a Tag", type: :request do
  describe "PATCH /api/v1/tags/:id" do
    describe "when authenticated" do
      include_context "with authenticated request"

      let!(:tag) { create(:tag, name: "Original Name", description: "Original description") }
      describe "successful update" do
        let(:params) do
          {
            tag: {
              name: "Updated Name",
              description: "Updated description"
            }
          }
        end

        before do
          patch "/api/v1/tags/#{tag.id}", params: params
        end

        it "returns status :ok" do
          expect(response).to have_http_status(:ok)
        end

        it "updates the tag" do
          expect(json_response.dig(:data, :tag, :name)).to eq("Updated Name")
          expect(json_response.dig(:data, :tag, :description)).to eq("Updated description")
          expect(json_response.dig(:data, :tag, :id)).to eq(tag.id)
        end

        it "actually updates the record in database" do
          tag.reload
          expect(tag.name).to eq("Updated Name")
          expect(tag.description).to eq("Updated description")
        end

        it "updates the slug when name changes" do
          expect(json_response.dig(:data, :tag, :slug)).to eq("updated-name")
        end
      end

      describe "updating only name" do
        let(:params) { {tag: {name: "New Name"}} }

        before do
          patch "/api/v1/tags/#{tag.id}", params: params
        end

        it "updates name and keeps description unchanged" do
          expect(json_response.dig(:data, :tag, :name)).to eq("New Name")
          expect(json_response.dig(:data, :tag, :description)).to eq("Original description")
        end
      end

      describe "updating only description" do
        let(:params) { {tag: {description: "New description"}} }

        before do
          patch "/api/v1/tags/#{tag.id}", params: params
        end

        it "updates description and keeps name unchanged" do
          expect(json_response.dig(:data, :tag, :name)).to eq("Original Name")
          expect(json_response.dig(:data, :tag, :description)).to eq("New description")
        end
      end

      describe "clearing description" do
        let(:params) { {tag: {description: ""}} }

        before do
          patch "/api/v1/tags/#{tag.id}", params: params
        end

        it "clears the description" do
          expect(json_response.dig(:data, :tag, :description)).to eq("")
        end
      end

      describe "validation errors" do
        context "with empty name" do
          let(:params) { {tag: {name: ""}} }

          before do
            patch "/api/v1/tags/#{tag.id}", params: params
          end

          it "returns status :unprocessable_content" do
            expect(response).to have_http_status(:unprocessable_content)
          end

          it "returns structured error response" do
            expect(json_response).to have_key(:error)
            expect(json_response.dig(:error, :errors, :name)).to be_present
          end

          it "does not update the tag" do
            tag.reload
            expect(tag.name).to eq("Original Name")
          end
        end

        context "with name too long" do
          let(:long_name) { "a" * 101 }
          let(:params) { {tag: {name: long_name}} }

          before do
            patch "/api/v1/tags/#{tag.id}", params: params
          end

          it "returns status :unprocessable_content" do
            expect(response).to have_http_status(:unprocessable_content)
          end

          it "includes error about name length" do
            expect(json_response.dig(:error, :errors, :name)).to be_present
            expect(json_response.dig(:error, :errors, :name).first).to match(/too long/i)
          end
        end

        context "with description too long" do
          let(:long_description) { "a" * 501 }
          let(:params) { {tag: {description: long_description}} }

          before do
            patch "/api/v1/tags/#{tag.id}", params: params
          end

          it "returns status :unprocessable_content" do
            expect(response).to have_http_status(:unprocessable_content)
          end

          it "includes error about description length" do
            expect(json_response.dig(:error, :errors, :description)).to be_present
            expect(json_response.dig(:error, :errors, :description).first).to match(/too long/i)
          end
        end
      end

      describe "duplicate name/slug handling" do
        let!(:other_tag) { create(:tag, name: "Other Tag") }

        context "when updating to existing tag name" do
          let(:params) { {tag: {name: "Other Tag"}} }

          before do
            patch "/api/v1/tags/#{tag.id}", params: params
          end

          it "generates unique slug with counter" do
            expect(response).to have_http_status(:ok)
            expect(json_response.dig(:data, :tag, :slug)).to match(/other-tag-\d+/)
          end
        end
      end

      describe "preserving usage_count" do
        let(:params) { {tag: {name: "New Name", usage_count: 999}} }

        before do
          tag.update_column(:usage_count, 42)
          patch "/api/v1/tags/#{tag.id}", params: params
        end

        it "does not allow updating usage_count" do
          expect(json_response.dig(:data, :tag, :usage_count)).to eq(42)
        end
      end

      describe "error cases" do
        context "with non-existent tag ID" do
          before do
            patch "/api/v1/tags/#{SecureRandom.uuid}", params: {tag: {name: "New Name"}}
          end

          it "returns status :not_found" do
            expect(response).to have_http_status(:not_found)
          end

          it "returns structured error response" do
            expect(json_response).to have_key(:error)
            expect(json_response[:error][:code]).to eq("record_not_found")
          end
        end
      end
    end

    describe "when not authenticated" do
      let!(:tag) { create(:tag, name: "Original Name") }

      it "returns 401 Unauthorized" do
        patch "/api/v1/tags/#{tag.id}", params: {tag: {name: "New Name"}}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
