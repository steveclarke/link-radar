require "simplecov-review"

SimpleCov.start "rails" do
  # You can enable SimpleCov with an environment variable
  # Uncomment the line below if you want to only run it when specified
  # skip_coverage unless ENV['COVERAGE']

  enable_coverage :branch

  # Exclude gems and other files you don't want to be evaluated
  # add_filter "/lib/"
  add_filter "/bin/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_filter "/config/"
  add_filter "/test/"
  add_filter "/spec/"

  # Exclude ruby_llm generated models - these are third-party gem integrations
  add_filter "app/models/chat.rb"
  add_filter "app/models/message.rb"
  add_filter "app/models/tool_call.rb"
  add_filter "app/models/model.rb"

  add_filter "/lib/dev/"
  add_filter "/lib/generators/"

  # Group files together in the HTML report
  # add_group "Controllers", "app/controllers"
  # add_group "Models", "app/models"
  # add_group "Services", "app/services"
  # add_group "Jobs", "app/jobs"
  # add_group "Policies", "app/policies"
  # add_group "Mailers", "app/mailers"
  # add_group "Helpers", "app/helpers"
  # add_group "Validators", "app/validators"
  # add_group "Uploaders", "app/uploaders"

  # Set minimum coverage percentage expected
  # minimum_coverage line: 80

  # You can refuse coverage dropping between test runs
  # maximum_coverage_drop 5

  # Use both HTML and Review formatters
  formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::ReviewFormatter
  ]
  formatter SimpleCov::Formatter::MultiFormatter.new(formatters)

  # Merge results from multiple test suites
  use_merging true
  merge_timeout 3600

  # Track files even if they don't have a matching test
  # track_files "app/**/*.rb"
end
