# frozen_string_literal: true

module LinkRadar
  module SampleData
    module Links
      module_function

      TAG_POOL = [
        "Ruby", "Rails", "JavaScript", "TypeScript", "API", "Tutorial",
        "News", "Documentation", "Best Practices", "Performance",
        "Security", "Testing", "DevOps", "Database", "Frontend",
        "Backend", "Design", "UX", "Mobile", "Web Development"
      ].freeze

      ERROR_MESSAGES = [
        "Connection timeout after 15 seconds",
        "HTTP 404 Not Found",
        "HTTP 403 Forbidden",
        "SSL certificate verification failed",
        "HTTP 500 Internal Server Error",
        "Connection refused by host",
        "DNS resolution failed",
        "Too many redirects (>5)",
        "HTTP 503 Service Unavailable",
        "Invalid SSL certificate"
      ].freeze

      def call(success: 70, pending: 20, failed: 10)
        total = success + pending + failed
        distribution = build_state_distribution(success: success, pending: pending, failed: failed)

        $stdout.puts "Creating #{total} sample links..."
        total.times do
          state = weighted_random_state(distribution)
          Link.create!(build_link_attributes(state))
        end

        summarize!
      end

      # Private helper methods

      def build_state_distribution(success:, pending:, failed:)
        states = []
        states.concat([:success] * success)
        states.concat([:pending] * pending)
        states.concat([:failed] * failed)
        states.shuffle
      end

      def weighted_random_state(distribution)
        distribution.shift || :success
      end

      def build_link_attributes(state)
        url = generate_url
        base_attrs = {
          url: url,
          submitted_url: maybe_add_utm_params(url),
          tag_names: random_tags,
          fetch_state: state.to_s
        }

        case state
        when :success
          build_successful_attributes(base_attrs)
        when :failed
          build_failed_attributes(base_attrs)
        else # :pending
          build_pending_attributes(base_attrs)
        end
      end

      def build_successful_attributes(base_attrs)
        title = Faker::Hacker.say_something_smart
        note = Faker::Lorem.paragraph(sentence_count: 2)
        image_url = Faker::LoremFlickr.image(size: "1200x630", search_terms: ["technology"])
        content = generate_content
        timestamps = generate_timestamps(from: 90.days.ago, fetch_delay: 1..300)

        base_attrs.merge(
          title: title,
          note: note,
          image_url: image_url,
          content_text: content[:text],
          raw_html: content[:html],
          fetched_at: timestamps[:fetched_at],
          metadata: generate_metadata(title, note, image_url),
          created_at: timestamps[:created_at],
          updated_at: timestamps[:fetched_at]
        )
      end

      def build_failed_attributes(base_attrs)
        timestamps = generate_timestamps(from: 30.days.ago, fetch_delay: 5..30)

        base_attrs.merge(
          fetch_error: ERROR_MESSAGES.sample,
          fetched_at: timestamps[:fetched_at],
          created_at: timestamps[:created_at],
          updated_at: timestamps[:fetched_at]
        )
      end

      def build_pending_attributes(base_attrs)
        timestamps = generate_timestamps(from: 7.days.ago)

        base_attrs.merge(
          created_at: timestamps[:created_at],
          updated_at: timestamps[:created_at]
        )
      end

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

      def generate_timestamps(from:, fetch_delay: nil)
        created_at = Faker::Time.between(from: from, to: Time.zone.now)
        timestamps = {created_at: created_at, updated_at: created_at}

        if fetch_delay
          timestamps[:fetched_at] = created_at + rand(fetch_delay).seconds
          timestamps[:updated_at] = timestamps[:fetched_at]
        end

        timestamps
      end

      def generate_content
        paragraphs = Array.new(rand(3..5)) { Faker::Lorem.paragraph(sentence_count: rand(3..7)) }
        {
          text: paragraphs.join("\n\n"),
          html: generate_html_content(paragraphs)
        }
      end

      def generate_metadata(title, note, image_url)
        {
          "og:title" => title,
          "og:description" => note,
          "og:image" => image_url,
          "og:type" => "article",
          "twitter:card" => "summary_large_image",
          "twitter:title" => title,
          "twitter:description" => note
        }
      end

      def generate_html_content(paragraphs)
        html = "<article>\n"
        paragraphs.each do |para|
          html += "  <p>#{para}</p>\n"
        end
        html += "</article>"
        html
      end

      def summarize!
        $stdout.puts "Sample data created successfully!"
        $stdout.puts "Total links: #{Link.count}"
        $stdout.puts "  - Success: #{Link.where(fetch_state: "success").count}"
        $stdout.puts "  - Pending: #{Link.where(fetch_state: "pending").count}"
        $stdout.puts "  - Failed: #{Link.where(fetch_state: "failed").count}"
        $stdout.puts "Total tags: #{Tag.count}"
        if defined?(LinkTag)
          $stdout.puts "Total link-tag associations: #{LinkTag.count}"
        end
      end
    end
  end
end
