# frozen_string_literal: true

class LlmConfig < ApplicationConfig
  attr_config(
    :openai_api_key,
    analysis_model: "gpt-4o-mini",
    max_tags_for_analysis: 5000
  )
end
