# frozen_string_literal: true

module LinkRadar
  module Ai
    # Schema definition for AI link analysis structured output
    #
    # This defines the expected JSON structure from the LLM's response.
    # Using RubyLLM::Schema provides:
    # - Clean Ruby DSL for schema definition
    # - Automatic handling of provider-specific requirements
    # - Type safety and validation
    # - Automatic JSON parsing
    #
    # @example
    #   response = chat.with_schema(LinkAnalysisSchema).ask(prompt)
    #   response.content # => {"note" => "...", "tags" => ["tag1", "tag2"]}
    #
    class LinkAnalysisSchema < RubyLLM::Schema
      string :note, description: "1-2 sentence note explaining why content is worth saving"
      array :tags, of: :string, description: "Relevant tags for the content (typically 3-7)"
    end
  end
end
