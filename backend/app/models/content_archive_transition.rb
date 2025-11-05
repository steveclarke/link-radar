# frozen_string_literal: true

# == Schema Information
#
# Table name: content_archive_transitions
#
#  id                 :uuid             not null, primary key
#  metadata           :jsonb
#  most_recent        :boolean          not null
#  sort_key           :integer          not null
#  to_state           :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  content_archive_id :uuid             not null
#
# Indexes
#
#  index_content_archive_transitions_on_content_archive_id  (content_archive_id)
#  index_content_archive_transitions_parent_most_recent     (content_archive_id,most_recent) UNIQUE WHERE most_recent
#  index_content_archive_transitions_parent_sort            (content_archive_id,sort_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (content_archive_id => content_archives.id) ON DELETE => cascade
#
class ContentArchiveTransition < ApplicationRecord
  # Associations
  belongs_to :content_archive, inverse_of: :content_archive_transitions

  # Validations
  validates :to_state, presence: true, inclusion: {in: ContentArchiveStateMachine.states}
  validates :sort_key, presence: true
  validates :most_recent, inclusion: {in: [true, false]}

  # Cleanup callback for transition deletion
  after_destroy :update_most_recent, if: :most_recent?

  private

  def update_most_recent
    last_transition = content_archive.content_archive_transitions.order(:sort_key).last
    return if last_transition.blank?

    last_transition.update_column(:most_recent, true)
  end
end
