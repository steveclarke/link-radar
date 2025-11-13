# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API: Create a Tag", type: :request do
  describe "POST /api/v1/tags" do
    describe "when authenticated" do
      include_context "with authenticated request"
      describe "successful creation" do
        let(:params) do
          {
            tag: {
              name: "Ruby on Rails",
              description: "A web application framework"
            }
          }
        end

        before do
          post "/api/v1/tags", params: params
        end

        it "returns status :created" do
          expect(response).to have_http_status(:created)
        end

        it "returns the created tag" do
          expect(json_response.dig(:data, :tag, :name)).to eq("Ruby on Rails")
          expect(json_response.dig(:data, :tag, :description)).to eq("A web application framework")
        end

        it "creates the tag in database" do
          expect(Tag.find_by(name: "Ruby on Rails")).to be_present
        end

        it "auto-generates a slug" do
          expect(json_response.dig(:data, :tag, :slug)).to eq("ruby-on-rails")
        end

        it "initializes usage_count to 0" do
          expect(json_response.dig(:data, :tag, :usage_count)).to eq(0)
        end
      end

      describe "creating tag without description" do
        let(:params) { {tag: {name: "JavaScript"}} }

        before do
          post "/api/v1/tags", params: params
        end

        it "creates the tag successfully" do
          expect(response).to have_http_status(:created)
          expect(json_response.dig(:data, :tag, :name)).to eq("JavaScript")
          expect(json_response.dig(:data, :tag, :description)).to be_nil
        end
      end

      describe "slug uniqueness handling" do
        let!(:existing_tag) { create(:tag, name: "Ruby") }

        context "when creating tag with same name" do
          let(:params) { {tag: {name: "Ruby"}} }

          before do
            post "/api/v1/tags", params: params
          end

          it "generates unique slug with counter" do
            expect(response).to have_http_status(:created)
            expect(json_response.dig(:data, :tag, :slug)).to match(/ruby-\d+/)
          end
        end
      end

      describe "validation errors" do
        context "with missing name" do
          let(:params) { {tag: {description: "A description without name"}} }

          before do
            post "/api/v1/tags", params: params
          end

          it "returns status :unprocessable_content" do
            expect(response).to have_http_status(:unprocessable_content)
          end

          it "returns structured error response" do
            expect(json_response).to have_key(:error)
            expect(json_response[:error]).to have_key(:code)
            expect(json_response[:error]).to have_key(:errors)
            expect(json_response[:error][:code]).to eq("validation_failed")
          end

          it "includes validation errors for name" do
            expect(json_response.dig(:error, :errors, :name)).to be_present
          end

          it "does not create the tag" do
            expect(Tag.count).to eq(0)
          end
        end

        context "with empty name" do
          let(:params) { {tag: {name: ""}} }

          before do
            post "/api/v1/tags", params: params
          end

          it "returns status :unprocessable_content" do
            expect(response).to have_http_status(:unprocessable_content)
          end

          it "includes validation error" do
            expect(json_response.dig(:error, :errors, :name)).to be_present
          end
        end

        context "with name too long" do
          let(:long_name) { "a" * 101 }
          let(:params) { {tag: {name: long_name}} }

          before do
            post "/api/v1/tags", params: params
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
          let(:params) do
            {
              tag: {
                name: "Valid Name",
                description: long_description
              }
            }
          end

          before do
            post "/api/v1/tags", params: params
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

      describe "parameter handling" do
        context "with extra unpermitted parameters" do
          let(:params) do
            {
              tag: {
                name: "Ruby",
                usage_count: 999, # Not permitted
                malicious: "hack" # Not permitted
              }
            }
          end

          before do
            post "/api/v1/tags", params: params
          end

          it "ignores unpermitted parameters" do
            expect(response).to have_http_status(:created)
            expect(json_response.dig(:data, :tag, :usage_count)).to eq(0) # Default value
            expect(json_response.dig(:data, :tag)).not_to have_key(:malicious)
          end
        end
      end
    end

    describe "when not authenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/tags", params: {tag: {name: "Ruby"}}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
