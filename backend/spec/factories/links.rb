# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id                :uuid             not null, primary key
#  metadata          :jsonb
#  note              :text
#  search_projection :text
#  submitted_url     :string(2048)     not null
#  url               :string(2048)     not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_links_on_created_at  (created_at)
#  index_links_on_metadata    (metadata) USING gin
#  index_links_on_url         (url) UNIQUE
#
FactoryBot.define do
  factory :link do
    sequence(:url) { |n| "https://example.com/page-#{n}" }
    submitted_url { url }
    note { "Personal notes about this link" }
  end
end
