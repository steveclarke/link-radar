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
        $stdout.puts "Creating sample links..."
        create_successful_links(success)
        create_pending_links(pending)
        create_failed_links(failed)
        summarize!
      end

      def create_successful_links(count)
        return if count.to_i <= 0

        $stdout.puts "Creating #{count} successful links..."
        count.to_i.times do
          url = Faker::Internet.url(host: Faker::Internet.domain_name, path: "/#{Faker::Internet.slug}")
          title = Faker::Hacker.say_something_smart
          note = Faker::Lorem.paragraph(sentence_count: 2)
          image_url = Faker::LoremFlickr.image(size: "1200x630", search_terms: ["technology"])

          paragraphs = Array.new(rand(3..5)) { Faker::Lorem.paragraph(sentence_count: rand(3..7)) }
          content_text = paragraphs.join("\n\n")
          raw_html = generate_html_content(paragraphs)

          submitted_url = if rand < 0.3
            "#{url}?utm_source=twitter&utm_medium=social&utm_campaign=share"
          else
            url
          end

          created_at = Faker::Time.between(from: 90.days.ago, to: Time.zone.now)
          fetched_at = created_at + rand(1..300).seconds

          tag_names = TAG_POOL.sample(rand(0..3))

          Link.create!(
            url: url,
            submitted_url: submitted_url,
            title: title,
            note: note,
            image_url: image_url,
            content_text: content_text,
            raw_html: raw_html,
            fetch_state: "success",
            fetched_at: fetched_at,
            metadata: generate_metadata(title, note, image_url),
            tag_names: tag_names,
            created_at: created_at,
            updated_at: fetched_at
          )
        end
      end

      def create_pending_links(count)
        return if count.to_i <= 0

        $stdout.puts "Creating #{count} pending links..."
        count.to_i.times do
          url = Faker::Internet.url(host: Faker::Internet.domain_name, path: "/#{Faker::Internet.slug}")

          submitted_url = if rand < 0.3
            "#{url}?utm_source=facebook&utm_medium=social"
          else
            url
          end

          created_at = Faker::Time.between(from: 7.days.ago, to: Time.zone.now)

          tag_names = TAG_POOL.sample(rand(0..3))

          Link.create!(
            url: url,
            submitted_url: submitted_url,
            fetch_state: "pending",
            tag_names: tag_names,
            created_at: created_at,
            updated_at: created_at
          )
        end
      end

      def create_failed_links(count)
        return if count.to_i <= 0

        $stdout.puts "Creating #{count} failed links..."
        count.to_i.times do |i|
          url = Faker::Internet.url(host: Faker::Internet.domain_name, path: "/#{Faker::Internet.slug}")

          submitted_url = if rand < 0.3
            "#{url}?utm_source=reddit&utm_medium=social"
          else
            url
          end

          created_at = Faker::Time.between(from: 30.days.ago, to: Time.zone.now)
          fetched_at = created_at + rand(5..30).seconds

          tag_names = TAG_POOL.sample(rand(0..3))

          Link.create!(
            url: url,
            submitted_url: submitted_url,
            fetch_state: "failed",
            fetch_error: ERROR_MESSAGES[i % ERROR_MESSAGES.length],
            fetched_at: fetched_at,
            tag_names: tag_names,
            created_at: created_at,
            updated_at: fetched_at
          )
        end
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
