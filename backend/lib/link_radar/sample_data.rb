# frozen_string_literal: true

module LinkRadar
  module SampleData
    module_function

    # Clears application data to prepare for fresh sample data generation
    def reset_database
      $stdout.puts "Clearing existing data..."
      Link.destroy_all
      Tag.destroy_all
    end

    # DSL entrypoint: dispatch to a generator module by type symbol
    # Example: populate :links, success: 70, pending: 20, failed: 10
    def populate(type, **options)
      generator = resolve_generator(type)
      unless generator.respond_to?(:call)
        raise ArgumentError, "Generator #{generator} must implement .call(**options)"
      end
      generator.call(**options)
    end

    # Resolve symbol like :links to LinkRadar::SampleData::Links
    def resolve_generator(type)
      const_name = type.to_s.camelize
      const_get(const_name)
    rescue NameError
      raise ArgumentError, "Unknown sample data type: #{type}"
    end
    private_class_method :resolve_generator
  end
end
