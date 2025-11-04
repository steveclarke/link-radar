# A Result object returned by services and other classes to standardize return values.
# Provides methods to check for success or failure and retrieve data or errors.
#
# @example Basic usage
#   result = LinkRadar::Result.success(data: "Hello World")
#   if result.success?
#     puts result.data
#   end
#
# @example With errors
#   result = LinkRadar::Result.failure(["Invalid input", "Missing field"])
#   puts result.errors if result.failure?
#
module LinkRadar
  class Result
    attr_reader :success, :data, :errors

    # @param success [Boolean] whether the operation was successful
    # @param data [Object, nil] any data to return with the result
    # @param errors [Hash, Array<String>, String, nil] any errors to return with the result
    def initialize(success, data = nil, errors = [])
      @success = success
      @data = data
      @errors = errors.is_a?(Hash) ? errors : Array(errors)
    end

    # @return [Boolean] true if the operation was successful
    def success?
      @success
    end

    # @return [Boolean] true if the operation failed
    def failure?
      !success?
    end

    # Class method to create a success result
    # @param data [Object, nil] any data to return with the result
    # @return [Result] a success result with optional data
    def self.success(data = nil)
      new(true, data)
    end

    # Class method to create a failure result
    # @param errors [Array<String>, String] any errors to return with the result
    # @param data [Object, nil] any data to return with the result
    # @return [Result] a failure result with errors and optional data
    def self.failure(errors = [], data = nil)
      new(false, data, errors)
    end
  end
end
