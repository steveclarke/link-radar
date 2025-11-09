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
require "rails_helper"

RSpec.describe LinkTag, type: :model do
  # Create a fully valid link_tag for shoulda matchers
  let(:tag) { create(:tag) }
  let(:link) { create(:link) }
  subject { create(:link_tag, tag: tag, link: link) }

  describe "associations" do
    it { should belong_to(:link).required }
    it { should belong_to(:tag).required }
  end

  describe "validations" do
    describe "uniqueness validation" do
      before { create(:link_tag, tag: tag, link: link) }

      it "prevents duplicate tag assignments to the same link" do
        duplicate_assignment = build(:link_tag, tag: tag, link: link)
        expect(duplicate_assignment).not_to be_valid
        expect(duplicate_assignment.errors[:link_id]).to include("has already been taken")
      end

      it "allows same tag on different links" do
        other_link = create(:link)
        new_assignment = build(:link_tag, tag: tag, link: other_link)
        expect(new_assignment).to be_valid
      end

      it "allows different tags on same link" do
        other_tag = create(:tag, name: "other-tag")
        new_assignment = build(:link_tag, tag: other_tag, link: link)
        expect(new_assignment).to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "after_create :increment_tag_usage" do
      it "increments the tag's usage count" do
        tag = create(:tag, usage_count: 5)
        link = create(:link)

        expect {
          create(:link_tag, tag: tag, link: link)
        }.to change { tag.reload.usage_count }.from(5).to(6)
      end

      it "updates the tag's last_used_at timestamp" do
        tag = create(:tag, last_used_at: 1.day.ago)
        link = create(:link)
        old_timestamp = tag.last_used_at

        create(:link_tag, tag: tag, link: link)

        expect(tag.reload.last_used_at).to be > old_timestamp
        expect(tag.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end

    describe "after_destroy :decrement_tag_usage" do
      it "decrements the tag's usage count" do
        tag = create(:tag, usage_count: 5)
        link = create(:link)
        link_tag = create(:link_tag, tag: tag, link: link)

        expect {
          link_tag.destroy
        }.to change { tag.reload.usage_count }.by(-1)
      end

      it "does not decrement below zero" do
        tag = create(:tag, usage_count: 0)
        link = create(:link)
        link_tag = create(:link_tag, tag: tag, link: link)

        # Reset to 0 after creation incremented it
        tag.update_column(:usage_count, 0)

        expect {
          link_tag.destroy
        }.not_to change { tag.reload.usage_count }
      end
    end
  end

  describe "edge cases" do
    it "handles deletion of associated link" do
      link_tag = create(:link_tag, tag: tag, link: link)
      link.destroy
      expect { link_tag.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "handles deletion of associated tag" do
      link_tag = create(:link_tag, tag: tag, link: link)
      tag.destroy
      expect { link_tag.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
