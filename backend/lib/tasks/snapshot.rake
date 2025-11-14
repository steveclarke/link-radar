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
    unless args[:file]
      puts "Usage: rake snapshot:import[filename.json] or rake snapshot:import[filename.json,update]"
      puts "  Mode: skip (default) or update"
      exit 1
    end

    # Determine file path (check snapshots/imports/ directory first, then treat as full path)
    file_path = if File.exist?(args[:file])
      args[:file]
    else
      Rails.root.join("snapshots", "imports", args[:file])
    end

    unless File.exist?(file_path)
      puts "✗ File not found: #{file_path}"
      exit 1
    end

    mode = args[:mode].presence&.to_sym || :skip

    puts "Importing links from #{file_path}..."
    puts "Mode: #{mode}"

    importer = LinkRadar::DataImport::Importer.new(file_path: file_path, mode: mode)
    result = importer.call

    if result.success?
      puts "✓ Import successful!"
      puts "  Links imported: #{result.data[:links_imported]}"
      puts "  Links skipped: #{result.data[:links_skipped]}"
      puts "  Tags created: #{result.data[:tags_created]}"
      puts "  Tags reused: #{result.data[:tags_reused]}"
    else
      puts "✗ Import failed:"
      result.errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end
end
