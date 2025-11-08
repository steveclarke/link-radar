class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include Pagy::Method
  include VersionHeader

  before_action :authenticate_api_request!

  private

  def authenticate_api_request!
    authenticate_or_request_with_http_token do |token, options|
      # Use secure_compare to prevent timing attacks
      ActiveSupport::SecurityUtils.secure_compare(token, CoreConfig.api_key)
    end
  end

  def request_http_token_authentication(realm = "Application", message = nil)
    # Override the default behavior to return JSON instead of plain text
    render json: {error: "Unauthorized", message: "Invalid or missing API token"}, status: :unauthorized
  end
end
