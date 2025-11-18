require_relative "../dev/sample_data"

namespace :sample_data do
  desc "Load sample data (calls Dev::SampleData DSL)"
  task load: :environment do
    Dev::SampleData.reset_database
    Dev::SampleData.populate :links
  end

  desc "Clear sample data (Links, Tags)"
  task clear: :environment do
    Dev::SampleData.reset_database
  end
end
