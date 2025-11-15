# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id                :uuid             not null, primary key
#  note              :text
#  search_projection :text
#  url               :string(2048)     not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_links_on_created_at  (created_at)
#  index_links_on_url         (url) UNIQUE
#
FactoryBot.define do
  factory :link do
    sequence(:url) { |n| "https://example.com/page-#{n}" }
    note { "Personal notes about this link" }
  end
end
