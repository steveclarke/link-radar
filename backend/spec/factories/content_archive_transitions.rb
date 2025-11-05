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
#  fk_rails_...  (content_archive_id => content_archives.id)
#
FactoryBot.define do
  factory :content_archive_transition do
    # Associations
    content_archive

    # Required fields
    to_state { "pending" }
    sort_key { 1 }
    most_recent { true }

    # Optional JSONB metadata
    metadata { {} }
  end
end
