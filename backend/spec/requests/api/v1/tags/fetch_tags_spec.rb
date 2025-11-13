# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API: Fetch Tags", type: :request do
  describe "GET /api/v1/tags" do
    describe "when authenticated" do
      include_context "with authenticated request"
      describe "basic retrieval" do
        let!(:tags) do
          [
            create(:tag, name: "Ruby", usage_count: 10),
            create(:tag, name: "JavaScript", usage_count: 5),
            create(:tag, name: "Python", usage_count: 15)
          ]
        end

        before do
          get "/api/v1/tags"
        end

        it "returns status :ok" do
          expect(response).to have_http_status(:ok)
        end

        it "returns all tags in alphabetical order by default" do
          expect(json_response.dig(:data, :tags)).to be_an(Array)
          expect(json_response.dig(:data, :tags).size).to eq(3)

          # Should be alphabetically ordered: JavaScript, Python, Ruby
          names = json_response.dig(:data, :tags).map { |t| t[:name] }
          expect(names).to eq(["JavaScript", "Python", "Ruby"])
        end

        it "includes tag attributes" do
          tag = json_response.dig(:data, :tags).first
          expect(tag).to have_key(:id)
          expect(tag).to have_key(:name)
          expect(tag).to have_key(:slug)
          expect(tag).to have_key(:description)
          expect(tag).to have_key(:usage_count)
          expect(tag).to have_key(:last_used_at)
          expect(tag).to have_key(:created_at)
          expect(tag).to have_key(:updated_at)
        end
      end

      describe "empty state" do
        before do
          get "/api/v1/tags"
        end

        it "returns empty array when no tags exist" do
          expect(json_response.dig(:data, :tags)).to eq([])
        end
      end

      describe "search functionality" do
        let!(:tags) do
          [
            create(:tag, name: "JavaScript", usage_count: 10),
            create(:tag, name: "Java", usage_count: 5),
            create(:tag, name: "Ruby", usage_count: 3),
            create(:tag, name: "Python", usage_count: 8)
          ]
        end

        context "with search parameter" do
          before do
            get "/api/v1/tags", params: {search: "java"}
          end

          it "returns matching tags" do
            expect(response).to have_http_status(:ok)
            tags = json_response.dig(:data, :tags)

            # Should return both JavaScript and Java
            names = tags.map { |t| t[:name] }
            expect(names).to include("JavaScript", "Java")
            expect(names).not_to include("Ruby", "Python")
          end

          it "includes usage_count for each tag" do
            tags = json_response.dig(:data, :tags)

            # All tags should have usage_count
            tags.each do |tag|
              expect(tag).to have_key(:usage_count)
              expect(tag[:usage_count]).to be_a(Integer)
            end
          end

          it "limits results to 20 tags" do
            # Create 25 tags that match
            25.times { |i| create(:tag, name: "JavaScript#{i}") }

            get "/api/v1/tags", params: {search: "javascript"}

            expect(json_response.dig(:data, :tags).size).to be <= 20
          end
        end

        context "with empty search parameter" do
          before do
            get "/api/v1/tags", params: {search: ""}
          end

          it "returns all tags alphabetically" do
            expect(json_response.dig(:data, :tags).size).to eq(4)
            names = json_response.dig(:data, :tags).map { |t| t[:name] }
            expect(names).to eq(["Java", "JavaScript", "Python", "Ruby"])
          end
        end

        context "with no matching results" do
          before do
            get "/api/v1/tags", params: {search: "nonexistent"}
          end

          it "returns empty array" do
            expect(json_response.dig(:data, :tags)).to eq([])
          end
        end
      end

      describe "sorting" do
        let!(:tags) do
          [
            create(:tag, name: "Zulu", usage_count: 5, created_at: 3.days.ago),
            create(:tag, name: "Alpha", usage_count: 10, created_at: 1.day.ago),
            create(:tag, name: "Beta", usage_count: 3, created_at: 2.days.ago)
          ]
        end

        context "sort by name ascending" do
          before do
            get "/api/v1/tags", params: {sort: "name:asc"}
          end

          it "returns tags sorted by name" do
            names = json_response.dig(:data, :tags).map { |t| t[:name] }
            expect(names).to eq(["Alpha", "Beta", "Zulu"])
          end
        end

        context "sort by name descending" do
          before do
            get "/api/v1/tags", params: {sort: "name:desc"}
          end

          it "returns tags sorted by name descending" do
            names = json_response.dig(:data, :tags).map { |t| t[:name] }
            expect(names).to eq(["Zulu", "Beta", "Alpha"])
          end
        end

        context "sort by usage_count descending" do
          before do
            get "/api/v1/tags", params: {sort: "usage_count:desc"}
          end

          it "returns tags sorted by usage count" do
            names = json_response.dig(:data, :tags).map { |t| t[:name] }
            expect(names).to eq(["Alpha", "Zulu", "Beta"])
          end
        end

        context "sort by created_at descending" do
          before do
            get "/api/v1/tags", params: {sort: "created_at:desc"}
          end

          it "returns tags sorted by creation date (newest first)" do
            names = json_response.dig(:data, :tags).map { |t| t[:name] }
            expect(names).to eq(["Alpha", "Beta", "Zulu"])
          end
        end
      end
    end

    describe "when not authenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/tags"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
