# frozen_string_literal: true

namespace :snapshot do
  desc "Export all links to JSON file (excludes ~temp~ tagged links)"
  task export: :environment do
    puts "Exporting links..."

    exporter = LinkRadar::DataExport::Exporter.new
    result = exporter.call

    if result.success?
      puts "✓ Export successful!"
      puts "  File: #{result.data[:file_path]}"
      puts "  Links: #{result.data[:link_count]}"
      puts "  Tags: #{result.data[:tag_count]}"
    else
      puts "✗ Export failed:"
      result.errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end

  desc "Import links from JSON file"
  task :import, [:file, :mode] => :environment do |_t, args|
    # Implementation in Phase 3
    puts "Import task not yet implemented"
  end
end

