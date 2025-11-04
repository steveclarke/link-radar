# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id           :uuid             not null, primary key
#  description  :text
#  last_used_at :datetime
#  name         :string(100)      not null
#  slug         :string(100)      not null
#  usage_count  :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_tags_on_name  (name)
#  index_tags_on_slug  (slug) UNIQUE
#
FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
  end
end
