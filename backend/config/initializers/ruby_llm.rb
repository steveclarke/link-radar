RubyLLM.configure do |config|
  config.openai_api_key = LlmConfig.openai_api_key
  config.default_model = LlmConfig.analysis_model
end
