module Api
  module V1
    class SnapshotController < ApplicationController
      # POST /api/v1/snapshot/export
      # Export all links to JSON file and return download URL
      def export
        exporter = LinkRadar::Snapshot::Exporter.new
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
          allowed_directory: LinkRadar::Snapshot::Exporter::EXPORT_DIR
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

        # Use persistent temp directory instead of system /tmp
        temp_dir = Rails.root.join(CoreConfig.snapshot_tmp_dir)
        FileUtils.mkdir_p(temp_dir)

        temp_filename = "import-#{SecureRandom.uuid}.json"
        temp_path = temp_dir.join(temp_filename)
        File.write(temp_path, uploaded_file.read)

        begin
          importer = LinkRadar::Snapshot::Importer.new(file_path: temp_path.to_s, mode: mode)
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
          File.delete(temp_path) if temp_path && File.exist?(temp_path)
        end
      end
    end
  end
end
