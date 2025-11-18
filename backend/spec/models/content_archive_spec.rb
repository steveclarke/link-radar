# frozen_string_literal: true

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
require "rails_helper"

RSpec.describe ContentArchive, type: :model do
  subject { create(:content_archive, :without_link_callback) }

  describe "associations" do
    it { should belong_to(:link).required }
    it { should have_many(:content_archive_transitions) }
  end

  describe "validations" do
    it { should validate_length_of(:title).is_at_most(500).allow_nil }
    it { should validate_length_of(:image_url).is_at_most(2048).allow_nil }

    it "allows nil title" do
      archive = build(:content_archive, :without_link_callback, title: nil)
      expect(archive).to be_valid
    end

    it "allows nil image_url" do
      archive = build(:content_archive, :without_link_callback, image_url: nil)
      expect(archive).to be_valid
    end
  end

  describe "association behavior" do
    it "is deleted when associated link is deleted (cascade)" do
      link = create(:link)
      archive = link.content_archive

      expect {
        link.destroy
      }.to change { ContentArchive.exists?(archive.id) }.from(true).to(false)
    end
  end

  describe "edge cases" do
    it "handles very long title at max length" do
      archive = build(:content_archive, :without_link_callback, title: "a" * 500)
      expect(archive).to be_valid
    end

    it "handles very long image_url at max length" do
      archive = build(:content_archive, :without_link_callback, image_url: "https://example.com/" + "a" * 2000)
      expect(archive).to be_valid
    end

    it "handles empty metadata jsonb" do
      archive = create(:content_archive, :without_link_callback, metadata: {})
      expect(archive.metadata).to eq({})
    end

    it "handles complex metadata jsonb" do
      complex_metadata = {
        "author" => "John Doe",
        "tags" => ["ruby", "rails"],
        "stats" => {"views" => 100, "likes" => 50}
      }
      archive = create(:content_archive, :without_link_callback, metadata: complex_metadata)
      expect(archive.reload.metadata).to eq(complex_metadata)
    end
  end
end
