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
end
