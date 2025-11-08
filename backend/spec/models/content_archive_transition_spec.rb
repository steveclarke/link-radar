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
require "rails_helper"

RSpec.describe ContentArchiveTransition, type: :model do
  it "has a valid factory" do
    expect(build(:content_archive_transition)).to be_valid
  end

  describe "associations" do
    it { should belong_to(:content_archive) }
  end

  describe "validations" do
    it { should validate_presence_of(:to_state) }
    it { should validate_inclusion_of(:to_state).in_array(ContentArchiveStateMachine.states) }
    it { should validate_presence_of(:sort_key) }
  end

  describe "metadata" do
    it "stores JSONB metadata" do
      metadata = {reason: "manual transition", user_id: "123"}
      transition = create(:content_archive_transition, metadata: metadata)

      expect(transition.metadata).to eq({
        "reason" => "manual transition",
        "user_id" => "123"
      })
    end

    it "defaults to empty hash" do
      transition = create(:content_archive_transition)
      expect(transition.metadata).to eq({})
    end
  end

  describe "after_destroy callback" do
    it "updates most_recent flag when most recent transition is destroyed" do
      content_archive = create(:content_archive, :without_link_callback)

      # Manually create multiple transitions to test the callback
      first_transition = create(:content_archive_transition, content_archive: content_archive, to_state: "pending", sort_key: 1, most_recent: false)
      second_transition = create(:content_archive_transition, content_archive: content_archive, to_state: "processing", sort_key: 2, most_recent: true)

      expect(first_transition.most_recent).to be(false)
      expect(second_transition.most_recent).to be(true)

      # Destroy the most recent transition
      second_transition.destroy!

      # Previous transition should now be marked as most recent
      expect(first_transition.reload.most_recent).to be(true)
    end
  end
end
