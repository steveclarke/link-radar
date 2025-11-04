# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id           :uuid             not null, primary key
#  description  :text
#  last_used_at :datetime
#  name         :string(100)      not null
#  slug         :string(100)      not null
#  usage_count  :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_tags_on_name  (name)
#  index_tags_on_slug  (slug) UNIQUE
#
require "rails_helper"

RSpec.describe Tag, type: :model do
  subject { build(:tag) }

  it_behaves_like "searchable model", {
    search_content_class: SearchContent::Tag,
    setup: ->(record) {
      record.update!(name: "JavaScript", description: "Programming language")
      ["JavaScript", "Programming"]
    }
  }

  describe "associations" do
    it { should have_many(:link_tags).dependent(:destroy) }
    it { should have_many(:links).through(:link_tags) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    # Note: slug is auto-generated from name, so we don't validate it directly
  end

  describe "#autocomplete" do
    it "returns alphabetical tags when query is blank" do
      create(:tag, name: "Zebra")
      create(:tag, name: "Apple")

      results = Tag.autocomplete("")

      expect(results.first.name).to eq("Apple")
    end

    it "searches tags and orders by usage count" do
      popular_tag = create(:tag, name: "JavaScript", usage_count: 10)
      unpopular_tag = create(:tag, name: "Java", usage_count: 1)

      results = Tag.autocomplete("java")

      expect(results).to include(popular_tag, unpopular_tag)
      expect(results.first).to eq(popular_tag)
    end
  end
end
