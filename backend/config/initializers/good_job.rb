good_job_config = GoodJobConfig.new

# Configure authentication in non-local environments
unless Rails.env.local?
  GoodJob::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(good_job_config.dashboard_username, username) &&
      ActiveSupport::SecurityUtils.secure_compare(good_job_config.dashboard_password, password)
  end
end

Rails.application.configure do
  config.good_job.execution_mode = Rails.env.development? ? :inline : :external

  # https://github.com/bensheldon/good_job?tab=readme-ov-file#cron-style-repeatingrecurring-jobs
  config.good_job.enable_cron = true
  config.good_job.cron = {
    rebuild_search_projections_job: {
      cron: "0 * * * *", # Every hour at minute 0
      class: "RebuildSearchProjectionsJob",
      args: []
    },
    cleanup_snapshots_job: {
      cron: "0 2 * * *", # Daily at 2:00 AM
      class: "CleanupSnapshotsJob",
      args: []
    }
  }
end
