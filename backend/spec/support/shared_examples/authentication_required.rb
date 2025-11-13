# frozen_string_literal: true

# Shared examples for testing authentication requirements
#
# Verifies that an endpoint requires authentication by asserting
# that unauthenticated requests receive a 401 Unauthorized response.
#
# @example Testing authentication requirement
#   context "when unauthenticated" do
#     it_behaves_like "authentication required", :get, "/api/v1/links"
#   end
RSpec.shared_examples "authentication required" do |method, path|
  it "returns 401 unauthorized without valid token" do
    send(method, path)
    expect(response).to have_http_status(:unauthorized)
  end
end
