# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "faker"

$stdout.puts "Clearing existing data..."
Link.destroy_all
Tag.destroy_all

$stdout.puts "Creating sample tags..."
TAG_POOL = [
  "Ruby", "Rails", "JavaScript", "TypeScript", "API", "Tutorial",
  "News", "Documentation", "Best Practices", "Performance",
  "Security", "Testing", "DevOps", "Database", "Frontend",
  "Backend", "Design", "UX", "Mobile", "Web Development"
]

$stdout.puts "Creating sample links..."

# Helper to generate metadata
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

# Helper to generate HTML content
def generate_html_content(paragraphs)
  html = "<article>\n"
  paragraphs.each do |para|
    html += "  <p>#{para}</p>\n"
  end
  html += "</article>"
  html
end

# 70 successful links with full content
$stdout.puts "Creating 70 successful links..."
70.times do
  url = Faker::Internet.url(host: Faker::Internet.domain_name, path: "/#{Faker::Internet.slug}")
  title = Faker::Hacker.say_something_smart
  note = Faker::Lorem.paragraph(sentence_count: 2)
  image_url = Faker::LoremFlickr.image(size: "1200x630", search_terms: ["technology"])

  paragraphs = Array.new(rand(3..5)) { Faker::Lorem.paragraph(sentence_count: rand(3..7)) }
  content_text = paragraphs.join("\n\n")
  raw_html = generate_html_content(paragraphs)

  # Add UTM parameters to some submitted URLs
  submitted_url = if rand < 0.3
    "#{url}?utm_source=twitter&utm_medium=social&utm_campaign=share"
  else
    url
  end

  created_at = Faker::Time.between(from: 90.days.ago, to: Time.zone.now)
  fetched_at = created_at + rand(1..300).seconds

  # Randomly assign 0-3 tags
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

# 20 pending links with minimal content
$stdout.puts "Creating 20 pending links..."
20.times do
  url = Faker::Internet.url(host: Faker::Internet.domain_name, path: "/#{Faker::Internet.slug}")

  # Add UTM parameters to some submitted URLs
  submitted_url = if rand < 0.3
    "#{url}?utm_source=facebook&utm_medium=social"
  else
    url
  end

  created_at = Faker::Time.between(from: 7.days.ago, to: Time.zone.now)

  # Randomly assign 0-3 tags
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

# 10 failed links with error messages
$stdout.puts "Creating 10 failed links..."
error_messages = [
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
]

10.times do |i|
  url = Faker::Internet.url(host: Faker::Internet.domain_name, path: "/#{Faker::Internet.slug}")

  submitted_url = if rand < 0.3
    "#{url}?utm_source=reddit&utm_medium=social"
  else
    url
  end

  created_at = Faker::Time.between(from: 30.days.ago, to: Time.zone.now)
  fetched_at = created_at + rand(5..30).seconds

  # Randomly assign 0-3 tags
  tag_names = TAG_POOL.sample(rand(0..3))

  Link.create!(
    url: url,
    submitted_url: submitted_url,
    fetch_state: "failed",
    fetch_error: error_messages[i],
    fetched_at: fetched_at,
    tag_names: tag_names,
    created_at: created_at,
    updated_at: fetched_at
  )
end

$stdout.puts "Seed data created successfully!"
$stdout.puts "Total links: #{Link.count}"
$stdout.puts "  - Success: #{Link.where(fetch_state: "success").count}"
$stdout.puts "  - Pending: #{Link.where(fetch_state: "pending").count}"
$stdout.puts "  - Failed: #{Link.where(fetch_state: "failed").count}"
$stdout.puts "Total tags: #{Tag.count}"
$stdout.puts "Total link-tag associations: #{LinkTag.count}"
