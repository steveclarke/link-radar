# frozen_string_literal: true

# == Schema Information
#
# Table name: link_tags
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  link_id    :uuid             not null
#  tag_id     :uuid             not null
#
# Indexes
#
#  index_link_tags_on_link_id             (link_id)
#  index_link_tags_on_link_id_and_tag_id  (link_id,tag_id) UNIQUE
#  index_link_tags_on_tag_id              (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (link_id => links.id)
#  fk_rails_...  (tag_id => tags.id)
#
FactoryBot.define do
  factory :link_tag do
    link
    tag
  end
end
