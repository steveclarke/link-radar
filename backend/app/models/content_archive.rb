# frozen_string_literal: true

# Represents archived web page content for a Link
#
# ContentArchive stores extracted content, metadata, and tracks archival status
# through a Statesman state machine. Each Link has one ContentArchive (one-to-one).
# == Schema Information
#
# Table name: content_archives
#
#  id            :uuid             not null, primary key
#  content_html  :text
#  content_text  :text
#  description   :text
#  error_message :text
#  fetched_at    :datetime
#  image_url     :string(2048)
#  metadata      :jsonb
#  title         :string(500)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  link_id       :uuid             not null
#
# Indexes
#
#  index_content_archives_on_content_text  (content_text) USING gin
#  index_content_archives_on_link_id       (link_id) UNIQUE
#  index_content_archives_on_metadata      (metadata) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (link_id => links.id) ON DELETE => cascade
#
class ContentArchive < ApplicationRecord
  # =============================================================================
  # Associations
  # =============================================================================

  belongs_to :link

  # =============================================================================
  # Validations
  # =============================================================================

  validates :title, length: {maximum: 500}, allow_nil: true
  validates :image_url, length: {maximum: 2048}, allow_nil: true
end
