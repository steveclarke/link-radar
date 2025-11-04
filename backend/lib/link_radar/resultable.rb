# A concern that provides the Result pattern for returning standardized success/failure objects.
# This allows any class to return consistent Result objects without inheriting from a base class.
# Provides both instance methods and class methods for maximum flexibility.
#
# Focused purely on Result pattern - does not include logging utilities to avoid conflicts.
#
# @example Usage in a service-like class (instance methods)
#   class MyProcessor
#     include LinkRadar::Resultable
#
#     def initialize(input)
#       @input = input
#     end
#
#     def call
#       if valid_input?
#         success(data: process(@input))
#       else
#         failure("Invalid input provided")
#       end
#     end
#   end
#
# @example Usage with class methods
#   class MyUtility
#     include LinkRadar::Resultable
#
#     def self.validate_data(input)
#       if input.valid?
#         success(input.processed_data)
#       else
#         failure("Validation failed")
#       end
#     end
#   end
#
module LinkRadar
  module Resultable
    extend ActiveSupport::Concern

    included do
      # Make helper methods available as class methods too
      extend ClassMethods
    end

    module ClassMethods
      # Creates a success result (class method version)
      # @param data [Object, nil] any data to return with the result
      # @return [LinkRadar::Result] a success result with optional data
      def success(data = nil)
        LinkRadar::Result.success(data)
      end

      # Creates a failure result (class method version)
      # @param errors [Array<String>, String] any errors to return with the result
      # @param data [Object, nil] any data to return with the result
      # @return [LinkRadar::Result] a failure result with errors and optional data
      def failure(errors = [], data = nil)
        LinkRadar::Result.failure(errors, data)
      end
    end

    protected

    # Creates a success result
    # @param data [Object, nil] any data to return with the result
    # @return [LinkRadar::Result] a success result with optional data
    def success(data = nil)
      LinkRadar::Result.success(data)
    end

    # Creates a failure result
    # @param errors [Array<String>, String] any errors to return with the result
    # @param data [Object, nil] any data to return with the result
    # @return [LinkRadar::Result] a failure result with errors and optional data
    def failure(errors = [], data = nil)
      LinkRadar::Result.failure(errors, data)
    end
  end
end
