# frozen_string_literal: true

module LinkRadar
  # Service object for securely downloading files with path traversal protection
  #
  # Validates user-supplied filenames and ensures they can only access files
  # within a specified allowed directory, preventing directory traversal attacks.
  #
  # @example
  #   result = LinkRadar::SecureFileDownload.call(
  #     filename: params[:filename],
  #     allowed_directory: Rails.root.join("exports")
  #   )
  #
  #   if result.success?
  #     send_file result.data.file_path, filename: result.data.safe_filename
  #   else
  #     # result.data contains error info with status
  #     render json: { error: result.errors }, status: result.data.status
  #   end
  class SecureFileDownload
    include LinkRadar::Resultable

    # Success data payload for secure file downloads
    SuccessData = Data.define(:file_path, :safe_filename)

    # Error data payload with HTTP status
    ErrorData = Data.define(:status)

    # @param filename [String] User-supplied filename
    # @param allowed_directory [Pathname, String] Directory where files must reside
    # @return [LinkRadar::Result] Success with SuccessData or failure with ErrorData
    def self.call(filename:, allowed_directory:)
      new(filename: filename, allowed_directory: allowed_directory).call
    end

    def initialize(filename:, allowed_directory:)
      @filename = filename
      @allowed_directory = Pathname.new(allowed_directory)
    end

    def call
      validate_filename!
      build_and_verify_path!

      success(SuccessData.new(
        file_path: @file_path,
        safe_filename: @safe_filename
      ))
    rescue SecurityError => e
      failure(e.message, ErrorData.new(status: :forbidden))
    rescue FileNotFoundError => e
      failure(e.message, ErrorData.new(status: :not_found))
    end

    private

    attr_reader :filename, :allowed_directory

    # Custom exception for file not found
    class FileNotFoundError < StandardError; end

    # Validates filename doesn't contain path traversal sequences
    def validate_filename!
      if filename.nil? || filename.empty?
        raise SecurityError, "Filename cannot be blank"
      end

      # Reject filenames with path separators (/, \) or leading dots
      if filename.include?("/") || filename.include?("\\") || filename.start_with?(".")
        raise SecurityError, "Invalid filename: path traversal attempt detected"
      end
    end

    # Builds file path and verifies it's within allowed directory
    def build_and_verify_path!
      # Use basename as additional safety measure to strip any path components
      @safe_filename = File.basename(filename)
      @file_path = allowed_directory.join(@safe_filename)

      # Check if file exists first
      unless File.exist?(@file_path)
        raise FileNotFoundError, "File not found"
      end

      # Verify the resolved path is still within the allowed directory
      # Using realpath to resolve any symlinks or relative paths
      begin
        unless @file_path.realpath.to_s.start_with?(allowed_directory.realpath.to_s)
          raise SecurityError, "File path outside allowed directory"
        end
      rescue Errno::ENOENT
        raise FileNotFoundError, "File not found"
      end
    end
  end
end
