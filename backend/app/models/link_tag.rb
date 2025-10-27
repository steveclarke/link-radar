# Join model connecting links and tags
#
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
class LinkTag < ApplicationRecord
  # Associations
  belongs_to :link
  belongs_to :tag

  # Validations
  validates :link_id, uniqueness: {scope: :tag_id}

  # Callbacks
  after_create :increment_tag_usage
  after_destroy :decrement_tag_usage

  private

  # Increment the tag's usage count and update last_used_at
  # @return [void]
  def increment_tag_usage
    tag.increment_usage!
  end

  # Decrement the tag's usage count
  # @return [void]
  def decrement_tag_usage
    tag.decrement_usage!
  end
end
