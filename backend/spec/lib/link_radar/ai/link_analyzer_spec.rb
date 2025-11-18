# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::Ai::LinkAnalyzer do
  let(:url) { "https://example.com/article" }
  let(:title) { "Example Article" }
  let(:content) { "This is example content about Ruby programming." }
  let(:description) { "An article about Ruby" }
  let(:author) { "John Doe" }

  # Mock LLM response matching LinkAnalysisSchema
  let(:llm_response) do
    {
      "note" => "A helpful article about Ruby programming with practical examples.",
      "tags" => ["Ruby", "Programming", "Tutorial"]
    }
  end

  before do
    # Mock RubyLLM.chat to return a chat instance
    # The chat instance responds to with_instructions, with_schema, and ask
    allow(RubyLLM).to receive(:chat).and_return(chat_instance)
  end

  let(:chat_instance) do
    instance_double(
      RubyLLM::Chat,
      with_instructions: instructions_instance,
      with_schema: schema_instance,
      ask: response_instance
    )
  end

  let(:instructions_instance) do
    instance_double(
      RubyLLM::Chat,
      with_schema: schema_instance
    )
  end

  let(:schema_instance) do
    instance_double(
      RubyLLM::Chat,
      ask: response_instance
    )
  end

  let(:response_instance) do
    # RubyLLM.ask returns a response object with .content that contains parsed JSON
    double(content: llm_response)
  end

  describe "#call" do
    context "successful analysis" do
      before do
        # Mock existing tags in database
        allow(Tag).to receive_message_chain(:order, :limit, :pluck).and_return(["Ruby", "JavaScript"])
      end

      it "returns success Result object" do
        result = described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        expect(result).to be_success
      end

      it "includes suggested_note in response data" do
        result = described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        expect(result.data[:suggested_note]).to eq(llm_response["note"])
      end

      it "includes suggested_tags array in response data" do
        result = described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        expect(result.data[:suggested_tags]).to be_a(Array)
        expect(result.data[:suggested_tags].length).to eq(3)
      end

      it "marks existing tags with exists: true" do
        result = described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        tags = result.data[:suggested_tags]
        ruby_tag = tags.find { |t| t[:name] == "Ruby" }

        expect(ruby_tag[:exists]).to be(true)
      end

      it "marks new tags with exists: false" do
        result = described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        tags = result.data[:suggested_tags]
        programming_tag = tags.find { |t| t[:name] == "Programming" }

        expect(programming_tag[:exists]).to be(false)
      end

      it "handles case-insensitive tag matching" do
        # Existing tags are lowercase
        allow(Tag).to receive_message_chain(:order, :limit, :pluck).and_return(["ruby", "javascript"])

        result = described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        tags = result.data[:suggested_tags]
        ruby_tag = tags.find { |t| t[:name] == "Ruby" }

        # Should match "ruby" even though AI suggested "Ruby"
        expect(ruby_tag[:exists]).to be(true)
      end

      it "calls RubyLLM.chat with configured model" do
        described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        expect(RubyLLM).to have_received(:chat).with(model: LlmConfig.analysis_model)
      end

      it "sets system instructions for AI" do
        described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        expect(chat_instance).to have_received(:with_instructions)
          .with(include("helpful assistant"))
      end

      it "applies LinkAnalysisSchema to response" do
        described_class.new(
          url: url,
          content: content,
          title: title
        ).call

        # Verify that with_schema was called somewhere in the chain
        expect(schema_instance).to have_received(:ask)
      end
    end

    context "input validation" do
      before do
        allow(Tag).to receive_message_chain(:order, :limit, :pluck).and_return([])
      end

      it "returns failure when URL is missing" do
        result = described_class.new(
          url: nil,
          content: content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("URL is required")
      end

      it "returns failure when title is missing" do
        result = described_class.new(
          url: url,
          content: content,
          title: nil
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Title is required")
      end

      it "returns failure when URL is blank string" do
        result = described_class.new(
          url: "",
          content: content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("URL is required")
      end

      it "returns failure when title is blank string" do
        result = described_class.new(
          url: url,
          content: content,
          title: ""
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("Title is required")
      end

      it "returns failure when content exceeds MAX_CONTENT_LENGTH (50,000 chars)" do
        oversized_content = "a" * 50_001

        result = described_class.new(
          url: url,
          content: oversized_content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to include("exceeds maximum length")
      end

      it "accepts content exactly at MAX_CONTENT_LENGTH" do
        max_content = "a" * 50_000
        allow(LinkRadar::ContentArchiving::UrlValidator).to receive_message_chain(:new, :call).and_return(double(failure?: false))

        result = described_class.new(
          url: url,
          content: max_content,
          title: title
        ).call

        # Should call LLM (or be a validation error from URL validator)
        expect(result).to be_success
      end

      context "URL validation via UrlValidator" do
        it "returns failure for invalid URL format" do
          allow(LinkRadar::ContentArchiving::UrlValidator)
            .to receive_message_chain(:new, :call)
            .and_return(double(failure?: true, errors: ["Invalid URL format"]))

          result = described_class.new(
            url: "not-a-valid-url",
            content: content,
            title: title
          ).call

          expect(result).to be_failure
          expect(result.errors.first).to eq("Invalid URL format")
        end

        it "delegates URL validation to UrlValidator" do
          url_validator_spy = instance_double(LinkRadar::ContentArchiving::UrlValidator)
          allow(LinkRadar::ContentArchiving::UrlValidator).to receive(:new).with(url).and_return(url_validator_spy)
          allow(url_validator_spy).to receive(:call).and_return(double(failure?: false))

          described_class.new(
            url: url,
            content: content,
            title: title
          ).call

          expect(LinkRadar::ContentArchiving::UrlValidator).to have_received(:new).with(url)
          expect(url_validator_spy).to have_received(:call)
        end
      end
    end

    context "privacy protection (SSRF)" do
      before do
        allow(Tag).to receive_message_chain(:order, :limit, :pluck).and_return([])
      end

      it "blocks localhost URLs" do
        allow(LinkRadar::ContentArchiving::UrlValidator)
          .to receive_message_chain(:new, :call)
          .and_return(double(failure?: true, errors: ["URL resolves to localhost"]))

        result = described_class.new(
          url: "http://localhost/article",
          content: content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to eq("URL resolves to localhost")
      end

      it "blocks 127.0.0.1 URLs" do
        allow(LinkRadar::ContentArchiving::UrlValidator)
          .to receive_message_chain(:new, :call)
          .and_return(double(failure?: true, errors: ["URL resolves to private IP address (SSRF protection)"]))

        result = described_class.new(
          url: "http://127.0.0.1/admin",
          content: content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to include("private IP")
      end

      it "blocks private IP ranges (192.168.x.x)" do
        allow(LinkRadar::ContentArchiving::UrlValidator)
          .to receive_message_chain(:new, :call)
          .and_return(double(failure?: true, errors: ["URL resolves to private IP address (SSRF protection)"]))

        result = described_class.new(
          url: "http://192.168.1.1/config",
          content: content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to include("private IP")
      end

      it "blocks private IP ranges (10.x.x.x)" do
        allow(LinkRadar::ContentArchiving::UrlValidator)
          .to receive_message_chain(:new, :call)
          .and_return(double(failure?: true, errors: ["URL resolves to private IP address (SSRF protection)"]))

        result = described_class.new(
          url: "http://10.0.0.1/internal",
          content: content,
          title: title
        ).call

        expect(result).to be_failure
        expect(result.errors.first).to include("private IP")
      end

      it "allows public URLs" do
        allow(LinkRadar::ContentArchiving::UrlValidator)
          .to receive_message_chain(:new, :call)
          .and_return(double(failure?: false))

        result = described_class.new(
          url: "https://www.example.com/article",
          content: content,
          title: title
        ).call

        # Should not fail on privacy grounds (will proceed to LLM or other errors)
        expect(result).to be_success
      end
    end
  end
end
