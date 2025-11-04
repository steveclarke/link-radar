# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id                :uuid             not null, primary key
#  content_text      :text
#  fetch_error       :text
#  fetch_state       :enum             default("pending"), not null
#  fetched_at        :datetime
#  image_url         :string(2048)
#  metadata          :jsonb
#  note              :text
#  raw_html          :text
#  search_projection :text
#  submitted_url     :string(2048)     not null
#  title             :string(500)
#  url               :string(2048)     not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_links_on_created_at   (created_at)
#  index_links_on_fetch_state  (fetch_state)
#  index_links_on_metadata     (metadata) USING gin
#  index_links_on_url          (url) UNIQUE
#
FactoryBot.define do
  factory :link do
    sequence(:url) { |n| "https://example.com/page-#{n}" }
    submitted_url { url }
    title { "Example Link" }
    content_text { "Sample content for testing search functionality" }
    note { "Personal notes about this link" }
    fetch_state { "pending" }
  end
end
