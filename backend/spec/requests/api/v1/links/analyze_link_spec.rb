# frozen_string_literal: true

require "rails_helper"

describe "API: Analyze Link Content" do
  let(:valid_params) do
    {
      url: "https://example.com/article",
      title: "Example Article",
      content: "This is some article content about Ruby programming.",
      description: "An article about Ruby",
      author: "John Doe"
    }
  end

  context "when unauthenticated" do
    it_behaves_like "authentication required", :post, "/api/v1/links/analyze"
  end

  context "when authenticated" do
    include_context "with authenticated request"

    describe "successful analysis" do
      before do
        # Mock the LinkAnalyzer service to return success
        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: true,
            data: {
              suggested_note: "A helpful article about Ruby programming.",
              suggested_tags: [
                {name: "Ruby", exists: true},
                {name: "Programming", exists: false},
                {name: "Web Development", exists: false}
              ]
            }
          )
        )

        post "/api/v1/links/analyze", params: valid_params
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns suggested_note" do
        expect(json_response.dig(:data, :suggested_note)).to eq("A helpful article about Ruby programming.")
      end

      it "returns suggested_tags array" do
        tags = json_response.dig(:data, :suggested_tags)
        expect(tags).to be_an(Array)
        expect(tags.size).to eq(3)
      end

      it "includes tag name and exists fields" do
        tags = json_response.dig(:data, :suggested_tags)
        first_tag = tags.first

        expect(first_tag).to have_key(:name)
        expect(first_tag).to have_key(:exists)
      end

      it "correctly marks existing tags" do
        tags = json_response.dig(:data, :suggested_tags)
        ruby_tag = tags.find { |t| t[:name] == "Ruby" }

        expect(ruby_tag[:exists]).to be(true)
      end

      it "correctly marks new tags" do
        tags = json_response.dig(:data, :suggested_tags)
        programming_tag = tags.find { |t| t[:name] == "Programming" }

        expect(programming_tag[:exists]).to be(false)
      end

      it "calls LinkAnalyzer with request parameters" do
        # Already posted in before block, just verify it was called with correct params
        expect(LinkRadar::Ai::LinkAnalyzer).to have_received(:new).at_least(:once).with(
          url: valid_params[:url],
          content: valid_params[:content],
          title: valid_params[:title],
          description: valid_params[:description],
          author: valid_params[:author]
        )
      end
    end

    describe "minimal request (required fields only)" do
      let(:minimal_params) do
        {
          url: "https://example.com/article",
          title: "Article Title",
          content: "Article content"
        }
      end

      before do
        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: true,
            data: {
              suggested_note: "A note",
              suggested_tags: [{name: "Tag1", exists: false}]
            }
          )
        )

        post "/api/v1/links/analyze", params: minimal_params
      end

      it "returns status :ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns suggestions" do
        expect(json_response.dig(:data, :suggested_note)).to be_present
        expect(json_response.dig(:data, :suggested_tags)).to be_present
      end

      it "handles optional fields as nil" do
        expect(LinkRadar::Ai::LinkAnalyzer).to have_received(:new).with(
          url: minimal_params[:url],
          content: minimal_params[:content],
          title: minimal_params[:title],
          description: nil,
          author: nil
        )
      end
    end

    describe "validation errors" do
      it "returns error when URL is missing" do
        params = valid_params.except(:url)

        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: false,
            errors: ["URL is required"]
          )
        )

        post "/api/v1/links/analyze", params: params

        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :message)).to include("URL is required")
      end

      it "returns error when title is missing" do
        params = valid_params.except(:title)

        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: false,
            errors: ["Title is required"]
          )
        )

        post "/api/v1/links/analyze", params: params

        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :message)).to include("Title is required")
      end

      it "returns error when content exceeds limit" do
        params = valid_params.merge(content: "a" * 50_001)

        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: false,
            errors: ["Content exceeds maximum length of 50000 characters"]
          )
        )

        post "/api/v1/links/analyze", params: params

        # Validation errors (ArgumentError) return 400 bad_request
        expect(response).to have_http_status(:bad_request)
      end

      it "returns error for private IP URL" do
        params = valid_params.merge(url: "http://192.168.1.1/admin")

        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: false,
            errors: ["URL resolves to private IP address (SSRF protection)"]
          )
        )

        post "/api/v1/links/analyze", params: params

        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig(:error, :message)).to include("private IP")
      end
    end

    describe "service errors" do
      it "returns error on unexpected service error" do
        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: false,
            errors: ["AI analysis failed. Please try again."]
          )
        )

        post "/api/v1/links/analyze", params: valid_params

        # Service failures are wrapped in ArgumentError by the controller, which returns 400
        expect(response).to have_http_status(:bad_request)
      end

      it "returns generic error message (doesn't expose internal details)" do
        allow(LinkRadar::Ai::LinkAnalyzer).to receive_message_chain(:new, :call).and_return(
          double(
            success?: false,
            errors: ["AI analysis failed. Please try again."]
          )
        )

        post "/api/v1/links/analyze", params: valid_params

        expect(json_response.dig(:error, :message)).not_to include("API key", "OpenAI", "internal")
      end
    end
  end
end
