module Api
  module V1
    class SnapshotController < ApplicationController
      # POST /api/v1/snapshot/export
      # Export all links to JSON file and return download URL
      def export
        exporter = LinkRadar::DataExport::Exporter.new
        result = exporter.call

        if result.success?
          # Extract filename from full path for download URL
          filename = File.basename(result.data[:file_path])

          render json: {
            data: {
              file_path: filename,
              link_count: result.data[:link_count],
              tag_count: result.data[:tag_count],
              download_url: "/api/v1/snapshot/exports/#{filename}"
            }
          }
        else
          render_error(
            code: :export_failed,
            message: result.errors.join(", "),
            status: :internal_server_error
          )
        end
      end

      # GET /api/v1/snapshot/exports/:filename
      # Download export file (requires authentication)
      def download
        result = LinkRadar::SecureFileDownload.call(
          filename: params[:filename],
          allowed_directory: LinkRadar::DataExport::Exporter::EXPORT_DIR
        )

        if result.success?
          send_file result.data.file_path,
            type: "application/json",
            disposition: "attachment",
            filename: result.data.safe_filename
        else
          case result.data.status
          when :not_found
            render_not_found
          when :forbidden
            render_error(
              code: :forbidden,
              message: result.errors.join(", "),
              status: :forbidden
            )
          end
        end
      end

      # POST /api/v1/snapshot/import
      # Import links from uploaded JSON file
      def import
        if params[:file].blank?
          render_error(
            code: :no_file_provided,
            message: "No file provided",
            status: :bad_request
          )
          return
        end

        # Get uploaded file
        uploaded_file = params[:file]
        mode = params[:mode].presence&.to_sym || :skip

        # Create temporary file for processing (uses OS temp directory)
        temp_file = Tempfile.new(["import-", ".json"])
        temp_file.write(uploaded_file.read)
        temp_file.rewind # Reset file pointer for reading

        begin
          importer = LinkRadar::DataImport::Importer.new(file_path: temp_file.path, mode: mode)
          result = importer.call

          if result.success?
            render json: {data: result.data}
          else
            render_error(
              code: :import_failed,
              message: result.errors.join(", "),
              status: :unprocessable_entity
            )
          end
        rescue => e
          render_error(
            code: :import_failed,
            message: "Import failed: #{e.message}",
            status: :internal_server_error
          )
        ensure
          # Clean up temp file - runs whether success, failure, or exception
          temp_file.close
          temp_file.unlink
        end
      end
    end
  end
end
