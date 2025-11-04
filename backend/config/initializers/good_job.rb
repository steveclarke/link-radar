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

  # Enable cron when you have scheduled jobs
  # config.good_job.enable_cron = true
  # config.good_job.cron = {
  #   example_job: {
  #     cron: "0 0 * * *",
  #     class: "ExampleJob",
  #     args: []
  #   }
  # }
end
