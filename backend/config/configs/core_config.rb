# frozen_string_literal: true

class CoreConfig < ApplicationConfig
  attr_config(
    :api_key,
    :cors_origins,
    :log_level,
    app_env: Rails.env,
    frontend_url: "http://localhost:9000"
  )
end
