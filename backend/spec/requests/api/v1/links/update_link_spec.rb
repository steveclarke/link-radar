# frozen_string_literal: true

require "rails_helper"

describe "API: Update a Link" do
  let(:link) { create(:link, url: "https://original.example.com", note: "Original note") }

  context "when unauthenticated" do
    it_behaves_like "authentication required", :patch, "/api/v1/links/#{SecureRandom.uuid}"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    let(:params) do
      {
        link: {
          url: "https://updated.example.com",
          note: "Updated note"
        }
      }
    end

    describe "successful update" do
      before do
        patch "/api/v1/links/#{link.id}", params: params
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "updates the link" do
        # URLs are normalized (trailing slash added)
        expect(json_response.dig(:data, :link, :url)).to eq("https://updated.example.com/")
        expect(json_response.dig(:data, :link, :note)).to eq(params.dig(:link, :note))
        expect(json_response.dig(:data, :link, :id)).to eq(link.id)
      end

      it "actually updates the record in database" do
        link.reload
        # URLs are normalized (trailing slash added)
        expect(link.url).to eq("https://updated.example.com/")
        expect(link.note).to eq(params.dig(:link, :note))
      end
    end

    describe "updating only URL" do
      let(:url_only_params) { {link: {url: "https://new-url.example.com"}} }

      before do
        patch "/api/v1/links/#{link.id}", params: url_only_params
      end

      it "updates URL and keeps note unchanged" do
        # URLs are normalized (trailing slash added)
        expect(json_response.dig(:data, :link, :url)).to eq("https://new-url.example.com/")
        expect(json_response.dig(:data, :link, :note)).to eq(link.note)
      end
    end

    describe "updating only note" do
      let(:note_only_params) { {link: {note: "Just updating the note"}} }

      before do
        patch "/api/v1/links/#{link.id}", params: note_only_params
      end

      it "updates note and keeps URL unchanged" do
        expect(json_response.dig(:data, :link, :note)).to eq("Just updating the note")
        expect(json_response.dig(:data, :link, :url)).to eq(link.url)
      end
    end

    describe "clearing the note" do
      let(:clear_note_params) { {link: {note: ""}} }

      before do
        patch "/api/v1/links/#{link.id}", params: clear_note_params
      end

      it "clears the note" do
        expect(json_response.dig(:data, :link, :note)).to eq("")
      end
    end

    describe "updating tags" do
      let(:tag1) { create(:tag, name: "old-tag") }
      let(:link_with_tags) { create(:link, tags: [tag1]) }
      let(:params_with_new_tags) do
        {
          link: {
            tag_names: ["new-tag-1", "new-tag-2"]
          }
        }
      end

      before do
        patch "/api/v1/links/#{link_with_tags.id}", params: params_with_new_tags
      end

      it "replaces tags" do
        tags = json_response.dig(:data, :link, :tags)
        tag_names = tags.pluck(:name)
        expect(tag_names).to contain_exactly("new-tag-1", "new-tag-2")
        expect(tag_names).not_to include("old-tag")
      end
    end

    describe "removing all tags" do
      let(:tag1) { create(:tag, name: "tag-to-remove") }
      let(:link_with_tags) { create(:link, tags: [tag1]) }
      let(:params_without_tags) { {link: {tag_names: []}} }

      before do
        patch "/api/v1/links/#{link_with_tags.id}", params: params_without_tags
      end

      it "removes all tags" do
        expect(json_response.dig(:data, :link, :tags)).to eq([])
      end
    end

    describe "validation errors" do
      context "with invalid URL format" do
        # Use a URL with invalid characters that Addressable will reject
        let(:invalid_params) { {link: {url: "http://exa mple.com"}} }

        before do
          patch "/api/v1/links/#{link.id}", params: invalid_params
        end

        it "returns status :unprocessable_content" do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns validation errors" do
          expect(json_response).to have_key(:error)
          expect(json_response.dig(:error, :errors, :url)).to be_present
          expect(json_response.dig(:error, :errors, :url).first).to match(/not a valid URL/i)
        end

        it "does not update the link" do
          link.reload
          # URL should remain normalized with trailing slash
          expect(link.url).to eq("https://original.example.com/")
        end
      end

      context "with empty URL" do
        let(:invalid_params) { {link: {url: ""}} }

        before do
          patch "/api/v1/links/#{link.id}", params: invalid_params
        end

        it "returns status :unprocessable_content" do
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "with URL too long" do
        let(:very_long_url) { "https://example.com/" + ("x" * 2048) }
        let(:invalid_params) { {link: {url: very_long_url}} }

        before do
          patch "/api/v1/links/#{link.id}", params: invalid_params
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
      let!(:other_link) { create(:link, url: "https://other.example.com") }
      let(:duplicate_params) { {link: {url: other_link.url}} }

      before do
        patch "/api/v1/links/#{link.id}", params: duplicate_params
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

      it "does not update the link" do
        link.reload
        # URL should remain normalized with trailing slash
        expect(link.url).to eq("https://original.example.com/")
      end
    end

    describe "updating to same URL" do
      let(:same_url_params) { {link: {url: link.url, note: "Different note"}} }

      before do
        patch "/api/v1/links/#{link.id}", params: same_url_params
      end

      it "allows updating with the same URL" do
        expect(response).to have_http_status(:ok)
        expect(json_response.dig(:data, :link, :note)).to eq("Different note")
      end
    end

    describe "non-existent link" do
      let(:non_existent_id) { SecureRandom.uuid }

      before do
        patch "/api/v1/links/#{non_existent_id}", params: params
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
  end
end
