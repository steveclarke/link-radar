# Concern for setting version headers on API responses
#
# Automatically adds the X-LinkRadar-Version header to all responses
# to help with API versioning and debugging.
#
# @example Including in a controller
#   class MyController < ActionController::API
#     include VersionHeader
#   end
module VersionHeader
  extend ActiveSupport::Concern

  included do
    before_action :set_version_header
  end

  private

  # Sets the X-LinkRadar-Version header on the response
  #
  # @return [void]
  def set_version_header
    response.set_header "X-LinkRadar-Version", Rails.configuration.x.version
  end
end
