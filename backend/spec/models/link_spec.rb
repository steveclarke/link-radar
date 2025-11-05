# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id                :uuid             not null, primary key
#  metadata          :jsonb
#  note              :text
#  search_projection :text
#  submitted_url     :string(2048)     not null
#  url               :string(2048)     not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_links_on_created_at  (created_at)
#  index_links_on_metadata    (metadata) USING gin
#  index_links_on_url         (url) UNIQUE
#
require "rails_helper"

RSpec.describe Link, type: :model do
  it_behaves_like "searchable model", {
    search_content_class: SearchContent::Link,
    setup: ->(record) {
      record.update!(note: "Ruby Programming - Great resource")
      ruby_tag = create(:tag, name: "Rails")
      record.tags << ruby_tag

      ["Ruby", "Programming", "Rails"]
    }
  }

  describe "associations" do
    it { should have_many(:link_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:link_tags) }
    it { should have_one(:content_archive).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:submitted_url) }
  end
end
