module ResponseHelpers
  # Renders a JSON error response with the given code, message, and HTTP status
  #
  # @param code [Symbol, String] the error code symbol or string
  # @param message [String] the error message
  # @param status [Symbol, Integer] the HTTP status code (e.g., :bad_request, 400)
  # @return [void]
  # @example
  #   render_error(
  #     code: :invalid_input,
  #     message: "Invalid parameters",
  #     status: :bad_request
  #   )
  def render_error(code:, message:, status:)
    render(json: error_json(code, message), status: status)
  end

  # Renders a standard 404 Not Found error response
  #
  # @return [void]
  def render_not_found
    render_error(
      code: :not_found,
      message: "Not found",
      status: :not_found
    )
  end

  # Renders a standard 401 Unauthorized error response
  #
  # @return [void]
  def render_unauthorized
    render_error(
      code: :unauthorized,
      message: "You do not have authorisation to access this page",
      status: :unauthorized
    )
  end

  # Renders a standard 403 Forbidden error response
  #
  # @return [void]
  def render_forbidden
    render_error(
      code: :forbidden,
      message: "You are forbidden to perform this action",
      status: :forbidden
    )
  end

  # Renders a validation error response, extracting details from the exception
  #
  # Handles both ActiveRecord::RecordInvalid and ActiveModel::ValidationError,
  # serializing the validation errors into a structured format.
  #
  # @param code [Symbol, String] the error code symbol or string
  # @param message [String] the primary error message
  # @param status [Symbol, Integer] the HTTP status code
  # @param exception [ActiveRecord::RecordInvalid, ActiveModel::ValidationError]
  #   the exception containing validation errors
  # @return [void]
  # @example
  #   render_validation_error(
  #     code: :validation_failed,
  #     message: "Validation failed",
  #     status: :unprocessable_content,
  #     exception: e
  #   )
  def render_validation_error(code:, message:, status:, exception:)
    # Both exception types respond to either .record or .model
    error_object = exception.try(:record) || exception.try(:model)

    # Fallback to simple error if we can't extract validation errors
    return render_error(code: code, message: message, status: status) unless error_object

    errors = error_object.errors.as_json
    json = error_json(code, message, errors)

    render json: json, status: status
  end

  private

  # Builds a structured error JSON response
  #
  # @param code [Symbol, String] the error code
  # @param message [String] the error message
  # @param errors [Hash, nil] optional validation errors hash
  # @return [Hash] the structured error JSON
  def error_json(code, message, errors = nil)
    json = {
      error: {
        code: code,
        message: message
      }
    }

    # Append validation errors when present
    if errors.present?
      json[:error][:errors] = errors
    end

    json
  end
end
