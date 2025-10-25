# Represents a captured link in LinkRadar
#
# == Schema Information
#
# Table name: links
#
#  id            :uuid             not null, primary key
#  content_text  :text
#  fetch_error   :text
#  fetch_state   :enum             default("pending"), not null
#  fetched_at    :datetime
#  image_url     :string(2048)
#  metadata      :jsonb
#  note          :text
#  raw_html      :text
#  submitted_url :string(2048)     not null
#  title         :string(500)
#  url           :string(2048)     not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_links_on_created_at   (created_at)
#  index_links_on_fetch_state  (fetch_state)
#  index_links_on_metadata     (metadata) USING gin
#  index_links_on_url          (url) UNIQUE
#
class Link < ApplicationRecord
  # Associations
  has_many :link_tags, dependent: :destroy
  has_many :tags, through: :link_tags

  # Virtual attribute for tag assignment
  attr_accessor :tag_names

  # Fetch state enum backed by Postgres enum type
  enum :fetch_state, {
    pending: "pending",
    success: "success",
    failed: "failed"
  }, prefix: true

  # Validations
  validates :url, presence: true, length: {maximum: 2048}
  validates :submitted_url, presence: true, length: {maximum: 2048}
  validates :title, length: {maximum: 500}
  validates :image_url, length: {maximum: 2048}

  # Callbacks
  # Check @tag_names (instance variable) to distinguish: nil (not provided) vs [] (clear tags)
  after_save :process_tag_names, if: -> { !@tag_names.nil? }

  private

  # Process tag names after save, wrapped in a transaction
  def process_tag_names
    transaction do
      assign_tags(@tag_names)
    end
  ensure
    # Clear the virtual attribute after processing
    @tag_names = nil
  end

  # Assign tags by name, creating new tags as needed
  # @param tag_names [Array<String>] array of tag names (empty array clears all tags)
  # @return [Array<Tag>] the assigned tags
  def assign_tags(tag_names)
    # Normalize tag names
    normalized_names = Array(tag_names).map(&:strip).compact_blank.uniq

    # Find or create tags
    new_tags = normalized_names.map do |name|
      Tag.find_or_create_by(name: name)
    end

    # Replace existing tags with new set (including empty array to clear all)
    self.tags = new_tags
  end
end
