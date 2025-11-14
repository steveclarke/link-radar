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
        filename = params[:filename]
        export_dir = LinkRadar::DataExport::Exporter::EXPORT_DIR
        file_path = export_dir.join(filename)

        # Security: Only allow downloads from snapshots/exports directory
        # Prevent directory traversal attacks
        unless file_path.to_s.start_with?(export_dir.to_s)
          render_error(
            code: :forbidden,
            message: "Invalid file path",
            status: :forbidden
          )
          return
        end

        unless File.exist?(file_path)
          render_not_found
          return
        end

        send_file file_path,
          type: "application/json",
          disposition: "attachment",
          filename: filename
      end

      # POST /api/v1/snapshot/import
      # Import links from uploaded JSON file
      def import
        # Implementation in Phase 3
        render_error(
          code: :not_implemented,
          message: "Import not yet implemented",
          status: :not_implemented
        )
      end
    end
  end
end
