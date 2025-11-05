# frozen_string_literal: true

module Dev
  module SampleData
    module Links
      module_function

      TAG_POOL = [
        "Ruby", "Rails", "JavaScript", "TypeScript", "API", "Tutorial",
        "News", "Documentation", "Best Practices", "Performance",
        "Security", "Testing", "DevOps", "Database", "Frontend",
        "Backend", "Design", "UX", "Mobile", "Web Development"
      ].freeze

      def call(success: 70, pending: 20, failed: 10)
        # Note: success/pending/failed parameters are no longer used since
        # Link model no longer has fetch_state. Kept for backward compatibility.
        total = success + pending + failed

        $stdout.puts "Creating #{total} sample links..."
        total.times do
          Link.create!(build_link_attributes)
        end

        summarize!
      end

      # Private helper methods

      def build_link_attributes
        url = generate_url
        timestamps = generate_timestamps(from: 90.days.ago)

        {
          url: url,
          submitted_url: maybe_add_utm_params(url),
          note: Faker::Lorem.paragraph(sentence_count: 2),
          tag_names: random_tags,
          created_at: timestamps[:created_at],
          updated_at: timestamps[:updated_at]
        }
      end

      # Note: fetch_state, title, image_url, content_text, raw_html, fetch_error, fetched_at
      # have been migrated to ContentArchive model. This sample data loader now only
      # creates basic Link records. ContentArchive records will be created automatically
      # via the Link after_create callback when that functionality is implemented.

      def generate_url
        Faker::Internet.url(
          host: Faker::Internet.domain_name,
          path: "/#{Faker::Internet.slug}"
        )
      end

      def maybe_add_utm_params(url)
        return url unless rand < 0.3

        sources = %w[twitter facebook reddit linkedin]
        source = sources.sample
        params = "utm_source=#{source}&utm_medium=social"
        params += "&utm_campaign=share" if rand < 0.5
        "#{url}?#{params}"
      end

      def random_tags
        TAG_POOL.sample(rand(0..3))
      end

      def generate_timestamps(from:)
        created_at = Faker::Time.between(from: from, to: Time.zone.now)
        {created_at: created_at, updated_at: created_at}
      end

      def summarize!
        $stdout.puts "Sample data created successfully!"
        $stdout.puts "Total links: #{Link.count}"
        $stdout.puts "Total tags: #{Tag.count}"
        if defined?(LinkTag)
          $stdout.puts "Total link-tag associations: #{LinkTag.count}"
        end
      end
    end
  end
end
