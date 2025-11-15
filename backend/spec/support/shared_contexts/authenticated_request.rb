# frozen_string_literal: true

# Shared context for authenticated API requests
#
# This context bypasses the authentication check for testing purposes,
# simulating a successfully authenticated request with a valid API token.
#
# @example Using in a request spec
#   RSpec.describe "API: Links" do
#     context "when authenticated" do
#       include_context "with authenticated request"
#
#       it "returns links" do
#         get "/api/v1/links"
#         expect(response).to have_http_status(:ok)
#       end
#     end
#   end
RSpec.shared_context "with authenticated request" do
  let(:api_token) { CoreConfig.api_key }
  let(:auth_headers) { {"Authorization" => "Bearer #{api_token}"} }

  # Bypass authentication for testing
  # In a real request, the token would be validated in ApplicationController
  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:authenticate_api_request!)
      .and_return(true)
  end
end
