# frozen_string_literal: true

module ResponseHelpers
  # Parse the API response body into a hash with indifferent access
  #
  # @return [ActiveSupport::HashWithIndifferentAccess] parsed JSON response
  # @example
  #   get "/api/v1/links"
  #   json_response[:data][:links]
  def json_response
    JSON.parse(response.body, object_class: ActiveSupport::HashWithIndifferentAccess)
  rescue
    {}
  end
end

RSpec.configure do |config|
  config.include ResponseHelpers, type: :request
end
