# frozen_string_literal: true

class CoreConfig < ApplicationConfig
  attr_config(
    :api_key,
    :cors_origins,
    :log_level,
    app_env: Rails.env,
    frontend_url: "http://localhost:9000"
  )

  # Override cors_origins to automatically convert string patterns to regex objects
  def cors_origins
    # Get the raw values from the config
    raw_origins = super

    # Convert patterns to regex
    raw_origins.map do |origin|
      case origin
      when /^chrome-extension:\/\*$/
        /chrome-extension:\/\/.*/
      when /^moz-extension:\/\*$/
        /moz-extension:\/\/.*/
      when /^.*\*.*$/
        Regexp.new(origin.gsub("*", ".*"))
      else
        origin
      end
    end
  end
end
