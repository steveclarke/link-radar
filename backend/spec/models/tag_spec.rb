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
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500).allow_nil }

    it "allows nil description" do
      tag = build(:tag, description: nil)
      expect(tag).to be_valid
    end

    describe "slug uniqueness" do
      it "validates slug uniqueness" do
        create(:tag, name: "Ruby", slug: "ruby")
        duplicate = create(:tag, name: "Python")

        # Manually set slug to duplicate value after creation
        duplicate.slug = "ruby"
        expect(duplicate).to be_invalid
        expect(duplicate.errors[:slug]).to include("has already been taken")
      end
    end

    it "enforces slug presence through callback" do
      # The callback always generates a slug from name, so we test
      # that the callback works correctly rather than testing nil slug
      tag = build(:tag, name: "Ruby")
      expect(tag.slug).to be_nil

      tag.valid?
      expect(tag.slug).to eq("ruby")
    end
  end

  describe "callbacks" do
    describe "before_validation :generate_slug" do
      it "generates slug from name on create" do
        tag = build(:tag, name: "Ruby on Rails", slug: nil)
        tag.valid?
        expect(tag.slug).to eq("ruby-on-rails")
      end

      it "regenerates slug when name changes" do
        tag = create(:tag, name: "JavaScript")
        expect(tag.slug).to eq("javascript")

        tag.name = "TypeScript"
        tag.valid?
        expect(tag.slug).to eq("typescript")
      end

      it "does not regenerate slug if name hasn't changed" do
        tag = create(:tag, name: "Ruby", slug: "custom-slug")
        original_slug = tag.slug

        tag.description = "A programming language"
        tag.save!

        expect(tag.slug).to eq(original_slug)
      end

      it "handles slug collisions by appending counter" do
        create(:tag, name: "Ruby")

        duplicate = build(:tag, name: "Ruby")
        duplicate.valid?
        expect(duplicate.slug).to eq("ruby-1")
        duplicate.save!

        another_duplicate = build(:tag, name: "Ruby")
        another_duplicate.valid?
        expect(another_duplicate.slug).to eq("ruby-2")
      end

      it "handles special characters in name" do
        tag = build(:tag, name: "C++ Programming!")
        tag.valid?
        expect(tag.slug).to eq("c-programming")
      end
    end
  end

  describe "instance methods" do
    describe "#increment_usage!" do
      it "increments usage_count" do
        tag = create(:tag, usage_count: 5)
        expect {
          tag.increment_usage!
        }.to change { tag.reload.usage_count }.from(5).to(6)
      end

      it "updates last_used_at timestamp" do
        tag = create(:tag, last_used_at: 1.day.ago)
        old_timestamp = tag.last_used_at

        tag.increment_usage!

        expect(tag.reload.last_used_at).to be > old_timestamp
        expect(tag.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end

    describe "#decrement_usage!" do
      it "decrements usage_count" do
        tag = create(:tag, usage_count: 5)
        expect {
          tag.decrement_usage!
        }.to change { tag.reload.usage_count }.from(5).to(4)
      end

      it "does not decrement below zero" do
        tag = create(:tag, usage_count: 0)
        result = tag.decrement_usage!

        expect(result).to eq(false)
        expect(tag.reload.usage_count).to eq(0)
      end
    end

    describe "#update_last_used!" do
      it "updates last_used_at timestamp" do
        tag = create(:tag, last_used_at: 1.day.ago)
        old_timestamp = tag.last_used_at

        tag.update_last_used!

        expect(tag.reload.last_used_at).to be > old_timestamp
      end
    end
  end

  describe "scopes" do
    describe ".alphabetical" do
      it "orders tags by name" do
        create(:tag, name: "Zebra")
        create(:tag, name: "Apple")
        create(:tag, name: "Banana")

        results = Tag.alphabetical
        expect(results.map(&:name)).to eq(["Apple", "Banana", "Zebra"])
      end
    end

    describe ".by_usage" do
      it "orders tags by usage_count descending, then name ascending" do
        popular = create(:tag, name: "Popular", usage_count: 100)
        unpopular = create(:tag, name: "Unpopular", usage_count: 1)
        medium = create(:tag, name: "Medium", usage_count: 50)
        also_popular = create(:tag, name: "Also Popular", usage_count: 100)

        results = Tag.by_usage
        expect(results.to_a).to eq([also_popular, popular, medium, unpopular])
      end
    end

    describe ".recently_used" do
      it "orders tags by last_used_at descending, then name ascending" do
        old = create(:tag, name: "Old", last_used_at: 1.week.ago)
        recent = create(:tag, name: "Recent", last_used_at: 1.hour.ago)
        very_old = create(:tag, name: "Very Old", last_used_at: 1.month.ago)
        also_recent = create(:tag, name: "Also Recent", last_used_at: 1.hour.ago)

        results = Tag.recently_used
        expect(results.to_a).to eq([also_recent, recent, old, very_old])
      end
    end
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
