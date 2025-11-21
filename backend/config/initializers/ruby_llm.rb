RubyLLM.configure do |config|
  config.openai_api_key = LlmConfig.openai_api_key
  config.default_model = LlmConfig.analysis_model

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
