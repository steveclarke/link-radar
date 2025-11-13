# frozen_string_literal: true

require "rails_helper"

describe "API: Create a Link" do
  context "when unauthenticated" do
    it_behaves_like "authentication required", :post, "/api/v1/links"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    let(:params) do
      {
        link: {
          url: "https://example.com/article",
          note: "Interesting article about Ruby"
        }
      }
    end

    describe "successful creation" do
      before do
        post "/api/v1/links", params: params
      end

      it "returns status :created" do
        expect(response).to have_http_status(:created)
      end

      it "creates the link" do
        expect(json_response.dig(:data, :link, :url)).to eq(params.dig(:link, :url))
        expect(json_response.dig(:data, :link, :note)).to eq(params.dig(:link, :note))
      end

      it "returns the created link with ID" do
        expect(json_response.dig(:data, :link, :id)).to be_present
      end

      it "includes empty tags array" do
        expect(json_response.dig(:data, :link, :tags)).to eq([])
      end

      it "actually creates the record in database" do
        link_id = json_response.dig(:data, :link, :id)
        expect(Link.find(link_id)).to be_present
      end
    end

    describe "creating with tags" do
      let(:params_with_tags) do
        {
          link: {
            url: "https://ruby-lang.org",
            note: "Ruby homepage",
            tag_names: ["ruby", "programming", "documentation"]
          }
        }
      end

      before do
        post "/api/v1/links", params: params_with_tags
      end

      it "creates the link with tags" do
        expect(response).to have_http_status(:created)
        tags = json_response.dig(:data, :link, :tags)
        expect(tags.size).to eq(3)
      end

      it "creates tag records" do
        tag_names = json_response.dig(:data, :link, :tags).pluck(:name)
        expect(tag_names).to contain_exactly("ruby", "programming", "documentation")
      end

      it "creates tags that can be reused" do
        expect(Tag.find_by(name: "ruby")).to be_present
        expect(Tag.find_by(name: "programming")).to be_present
      end
    end

    describe "creating with existing tags" do
      let!(:existing_tag) { create(:tag, name: "existing") }
      let(:params_with_existing_tag) do
        {
          link: {
            url: "https://example.com/page",
            tag_names: ["existing", "new-tag"]
          }
        }
      end

      before do
        post "/api/v1/links", params: params_with_existing_tag
      end

      it "reuses existing tags" do
        link_id = json_response.dig(:data, :link, :id)
        link = Link.find(link_id)
        expect(link.tags).to include(existing_tag)
      end

      it "does not duplicate existing tags" do
        expect(Tag.where(name: "existing").count).to eq(1)
      end

      it "creates new tags alongside existing ones" do
        tags = json_response.dig(:data, :link, :tags)
        tag_names = tags.pluck(:name)
        expect(tag_names).to contain_exactly("existing", "new-tag")
      end
    end

    describe "optional note field" do
      let(:params_without_note) do
        {
          link: {
            url: "https://example.com/no-note"
          }
        }
      end

      before do
        post "/api/v1/links", params: params_without_note
      end

      it "creates link without note" do
        expect(response).to have_http_status(:created)
        expect(json_response.dig(:data, :link, :note)).to be_nil
      end
    end

    describe "validation errors" do
      context "with missing URL" do
        let(:invalid_params) { {link: {note: "Note without URL"}} }

        before do
          post "/api/v1/links", params: invalid_params
        end

        it "returns status :unprocessable_content" do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns validation errors" do
          expect(json_response).to have_key(:error)
          expect(json_response[:error]).to have_key(:errors)
          expect(json_response.dig(:error, :errors, :url)).to be_present
        end
      end

      context "with invalid URL format" do
        # Use a URL with invalid characters that Addressable will reject
        let(:invalid_params) { {link: {url: "http://exa mple.com"}} }

        before do
          post "/api/v1/links", params: invalid_params
        end

        it "returns status :unprocessable_content" do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "includes error about invalid URL" do
          expect(json_response.dig(:error, :errors, :url)).to be_present
          expect(json_response.dig(:error, :errors, :url).first).to match(/not a valid URL/i)
        end
      end

      context "with URL too long" do
        let(:very_long_url) { "https://example.com/" + ("x" * 2048) }
        let(:invalid_params) { {link: {url: very_long_url}} }

        before do
          post "/api/v1/links", params: invalid_params
        end

        it "returns status :unprocessable_content" do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "includes error about URL length" do
          expect(json_response).to have_key(:error)
          expect(json_response.dig(:error, :errors, :url)).to be_present
          expect(json_response.dig(:error, :errors, :url).first).to match(/too long/i)
        end
      end
    end

    describe "duplicate URL constraint" do
      let!(:existing_link) { create(:link, url: "https://existing.example.com") }
      let(:duplicate_params) do
        {
          link: {
            url: existing_link.url,
            note: "Trying to duplicate"
          }
        }
      end

      before do
        post "/api/v1/links", params: duplicate_params
      end

      it "returns status :unprocessable_content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns structured error response" do
        expect(json_response).to have_key(:error)
        expect(json_response[:error]).to have_key(:code)
        expect(json_response[:error]).to have_key(:message)
        expect(json_response[:error]).to have_key(:errors)
        expect(json_response[:error][:code]).to eq("validation_failed")
      end

      it "does not create a duplicate link" do
        expect(Link.where(url: existing_link.url).count).to eq(1)
      end
    end

    describe "empty tag names" do
      let(:params_with_empty_tags) do
        {
          link: {
            url: "https://example.com/test",
            tag_names: []
          }
        }
      end

      before do
        post "/api/v1/links", params: params_with_empty_tags
      end

      it "creates link without tags" do
        expect(response).to have_http_status(:created)
        expect(json_response.dig(:data, :link, :tags)).to eq([])
      end
    end
  end
end
