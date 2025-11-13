# frozen_string_literal: true

require "rails_helper"

describe "API: Fetch Links" do
  context "when unauthenticated" do
    it_behaves_like "authentication required", :get, "/api/v1/links"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "basic retrieval" do
      before do
        create_list(:link, 3)
        get "/api/v1/links"
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns a list of links" do
        expect(json_response.dig(:data, :links).size).to eq(3)
      end

      it "includes link attributes" do
        link = json_response.dig(:data, :links).first
        expect(link).to have_key(:id)
        expect(link).to have_key(:url)
        expect(link).to have_key(:note)
        expect(link).to have_key(:tags)
      end

      it "includes pagination metadata" do
        expect(json_response).to have_key(:meta)
        expect(json_response[:meta]).to have_key(:pagination)
        pagination = json_response[:meta][:pagination]
        expect(pagination).to have_key(:page)
        expect(pagination).to have_key(:page_size)
      end
    end

    describe "empty state" do
      before do
        get "/api/v1/links"
      end

      it "returns an empty array when no links exist" do
        expect(json_response.dig(:data, :links)).to eq([])
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end
    end

    describe "search functionality" do
      let!(:ruby_link) { create(:link, url: "https://ruby-lang.org", note: "Ruby programming") }
      let!(:python_link) { create(:link, url: "https://python.org", note: "Python programming") }
      let!(:javascript_link) { create(:link, url: "https://javascript.info") }

      context "searching by URL" do
        before do
          get "/api/v1/links", params: {search: "ruby"}
        end

        it "returns matching links" do
          urls = json_response.dig(:data, :links).pluck(:url)
          expect(urls).to include(ruby_link.url)
          expect(urls).not_to include(python_link.url)
        end
      end

      context "searching by note" do
        before do
          get "/api/v1/links", params: {search: "programming"}
        end

        it "returns links with matching notes" do
          urls = json_response.dig(:data, :links).pluck(:url)
          expect(urls).to include(ruby_link.url, python_link.url)
          expect(urls).not_to include(javascript_link.url)
        end
      end
    end

    describe "sorting" do
      let!(:old_link) { create(:link, created_at: 2.days.ago) }
      let!(:new_link) { create(:link, created_at: 1.day.ago) }

      context "sorting by created_at descending" do
        before do
          get "/api/v1/links", params: {sort: "created_at:desc"}
        end

        it "returns links in descending order" do
          ids = json_response.dig(:data, :links).pluck(:id)
          expect(ids.first).to eq(new_link.id)
          expect(ids.last).to eq(old_link.id)
        end
      end

      context "sorting by created_at ascending" do
        before do
          get "/api/v1/links", params: {sort: "created_at:asc"}
        end

        it "returns links in ascending order" do
          ids = json_response.dig(:data, :links).pluck(:id)
          expect(ids.first).to eq(old_link.id)
          expect(ids.last).to eq(new_link.id)
        end
      end
    end

    describe "links with tags" do
      let(:tag1) { create(:tag, name: "ruby") }
      let(:tag2) { create(:tag, name: "tutorial") }
      let!(:link_with_tags) { create(:link, tags: [tag1, tag2]) }

      before do
        get "/api/v1/links"
      end

      it "includes associated tags" do
        link = json_response.dig(:data, :links).first
        expect(link[:tags]).to be_an(Array)
        expect(link[:tags].size).to eq(2)
      end

      it "includes tag attributes" do
        tag = json_response.dig(:data, :links).first[:tags].first
        expect(tag).to have_key(:id)
        expect(tag).to have_key(:name)
        expect(tag).to have_key(:slug)
      end
    end

    describe "pagination" do
      before do
        create_list(:link, 30)
      end

      it "limits results per page" do
        get "/api/v1/links", params: {page: 1}
        links_count = json_response.dig(:data, :links).size
        expect(links_count).to be <= 25 # Default Pagy limit
      end

      it "returns different results for different pages" do
        get "/api/v1/links", params: {page: 1}
        page1_ids = json_response.dig(:data, :links).pluck(:id)

        get "/api/v1/links", params: {page: 2}
        page2_ids = json_response.dig(:data, :links).pluck(:id)

        expect(page1_ids).not_to eq(page2_ids)
      end
    end
  end
end
