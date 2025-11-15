# frozen_string_literal: true

module LinkRadar
  module Snapshot
    # Service to clean up old snapshot files based on retention policies
    #
    # Removes files older than configured retention periods:
    # - Exports: Default 30 days (SNAPSHOT_EXPORTS_RETENTION_DAYS)
    # - Imports: Default 30 days (SNAPSHOT_IMPORTS_RETENTION_DAYS)
    # - Temp: Default 7 days (SNAPSHOT_TMP_RETENTION_DAYS)
    #
    # @example Clean up all snapshot directories
    #   cleaner = Cleaner.new
    #   result = cleaner.call
    #   result.data[:exports_deleted] # => 5
    #
    # @return [LinkRadar::Result] success with cleanup stats or failure
    class Cleaner
      include LinkRadar::Resultable

      def call
        stats = {
          exports_deleted: 0,
          imports_deleted: 0,
          tmp_deleted: 0
        }

        stats[:exports_deleted] = cleanup_directory(
          CoreConfig.snapshot_exports_dir,
          CoreConfig.snapshot_exports_retention_days
        )

        stats[:imports_deleted] = cleanup_directory(
          CoreConfig.snapshot_imports_dir,
          CoreConfig.snapshot_imports_retention_days
        )

        stats[:tmp_deleted] = cleanup_directory(
          CoreConfig.snapshot_tmp_dir,
          CoreConfig.snapshot_tmp_retention_days
        )

        success(stats)
      rescue => e
        failure("Snapshot cleanup failed: #{e.message}")
      end

      private

      def cleanup_directory(relative_path, retention_days)
        dir = Rails.root.join(relative_path)
        return 0 unless Dir.exist?(dir)

        cutoff_time = retention_days.days.ago
        deleted_count = 0

        Dir.glob(File.join(dir, "*")).each do |file_path|
          next if File.directory?(file_path)
          next if File.basename(file_path) == ".keep"

          if File.mtime(file_path) < cutoff_time
            File.delete(file_path)
            deleted_count += 1
            Rails.logger.info(
              "Deleted old snapshot file: #{file_path}"
            )
          end
        end

        deleted_count
      end
    end
  end
end
