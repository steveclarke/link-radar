# Global error handlers for common exceptions
#
# This concern provides centralized exception handling for controllers,
# eliminating the need for repetitive rescue blocks in individual actions.
# All handlers use the ResponseHelpers module for consistent error formatting.
#
# @example Including in a controller
#   class ApplicationController < ActionController::API
#     include ResponseHelpers
#     include ErrorHandlers
#   end
module ErrorHandlers
  extend ActiveSupport::Concern
  include ::ResponseHelpers

  included do
    # Handles ArgumentError exceptions
    # Raised when invalid arguments are passed to a method
    rescue_from ArgumentError do |e|
      render_error(
        code: :invalid_argument,
        message: e.message,
        status: :bad_request
      )
    end

    # Handles ActiveRecord::RecordNotFound exceptions
    # Raised when a record cannot be found by ID or other finder methods
    rescue_from ActiveRecord::RecordNotFound do |e|
      render_error(
        code: :record_not_found,
        message: e.message,
        status: :not_found
      )
    end

    # Handles ActiveRecord::RecordInvalid exceptions
    # Raised when attempting to save/create/update! an invalid record
    rescue_from ActiveRecord::RecordInvalid do |e|
      render_validation_error(
        code: :validation_failed,
        message: e.message,
        status: :unprocessable_entity,
        exception: e
      )
    end

    # Handles ActiveModel::ValidationError exceptions
    # Raised when validating a PORO with ActiveModel::Validations
    rescue_from ActiveModel::ValidationError do |e|
      render_validation_error(
        code: :validation_failed,
        message: e.message,
        status: :unprocessable_entity,
        exception: e
      )
    end

    # Handles ActiveRecord::RecordNotUnique exceptions
    # Raised when attempting to insert/update a record that violates
    # a unique constraint
    rescue_from ActiveRecord::RecordNotUnique do |e|
      render_error(
        code: :duplicate_record,
        message: "A record with this unique value already exists",
        status: :unprocessable_entity
      )
    end

    # Handles ActiveRecord::DeleteRestrictionError exceptions
    # Raised when attempting to delete a record that has dependent records
    # with a restrict_with_error or restrict_with_exception dependency
    rescue_from ActiveRecord::DeleteRestrictionError do |e|
      render_error(
        code: :delete_restriction,
        message: e.message,
        status: :unprocessable_entity
      )
    end
  end
end
