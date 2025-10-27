namespace :sample_data do
  desc "Load sample data (calls LinkRadar::SampleData DSL)"
  task load: :environment do
    LinkRadar::SampleData.reset_database
    LinkRadar::SampleData.populate :links
  end

  desc "Clear sample data (Links, Tags)"
  task clear: :environment do
    LinkRadar::SampleData.reset_database
  end
end
