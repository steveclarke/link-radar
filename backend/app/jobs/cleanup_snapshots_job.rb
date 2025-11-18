# frozen_string_literal: true

# Background job to clean up old snapshot files
#
# Runs on daily schedule via GoodJob cron to remove snapshot files
# (exports, imports, temp) older than configured retention periods.
#
# Schedule: Daily at 2:00 AM (see config/initializers/good_job.rb)
# Default retention:
# - Exports: 30 days (SNAPSHOT_EXPORTS_RETENTION_DAYS)
# - Imports: 30 days (SNAPSHOT_IMPORTS_RETENTION_DAYS)
# - Temp: 7 days (SNAPSHOT_TMP_RETENTION_DAYS)
#
# @example Manual execution
#   CleanupSnapshotsJob.perform_now
#
class CleanupSnapshotsJob < ApplicationJob
  queue_as :default

  def perform
    cleaner = LinkRadar::Snapshot::Cleaner.new
    result = cleaner.call

    if result.success?
      Rails.logger.info(
        "Snapshot cleanup completed: " \
        "#{result.data[:exports_deleted]} exports, " \
        "#{result.data[:imports_deleted]} imports, " \
        "#{result.data[:tmp_deleted]} temp files deleted"
      )
    else
      Rails.logger.error(
        "Snapshot cleanup failed: #{result.errors.join(", ")}"
      )
    end
  end
end
