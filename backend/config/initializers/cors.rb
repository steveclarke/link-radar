# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins CoreConfig.new.cors_origins

    resource "*",
      headers: :any,
      credentials: true,
      methods: %i[get post put patch delete options head],
      expose: [
        "X-LinkRadar-Version",
        "Content-Disposition", # Allows us to access filename from response headers in front-end
        "Authorization" # Allow extension to read Authorization header
      ]
  end
end
