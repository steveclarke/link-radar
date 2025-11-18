# frozen_string_literal: true

module Dev
  module SampleData
    module_function

    # Reset the database by clearing all links and tags
    def reset_database
      $stdout.puts "Clearing existing data..."

      # Clear link-tag associations first if the join table exists
      if ActiveRecord::Base.connection.table_exists?("link_tags")
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE link_tags RESTART IDENTITY CASCADE")
      end

      # Clear tags and links
      Tag.destroy_all
      Link.destroy_all

      $stdout.puts "Database cleared."
    end

    # Populate sample data for a specific resource
    # @param resource [Symbol] The resource to populate (:links, etc.)
    # @param options [Hash] Options to pass to the resource generator
    def populate(resource, **options)
      case resource
      when :links
        require_relative "sample_data/links"
        Dev::SampleData::Links.call(**options)
      else
        raise ArgumentError, "Unknown sample data resource: #{resource}"
      end
    end
  end
end
