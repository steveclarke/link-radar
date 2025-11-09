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
  include ActiveJob::TestHelper

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
    subject { build(:link) }

    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:submitted_url) }
    it { should validate_length_of(:url).is_at_most(2048) }
    it { should validate_length_of(:submitted_url).is_at_most(2048) }
    it { should validate_uniqueness_of(:url) }
  end

  describe "after_create :create_content_archive_and_enqueue_job" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      clear_performed_jobs

      example.run
    ensure
      clear_enqueued_jobs
      clear_performed_jobs
      ActiveJob::Base.queue_adapter = original_adapter
    end

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    context "when archival is enabled" do
      let(:config) { instance_double(ContentArchiveConfig, enabled: true) }

      before do
        allow(ContentArchiveConfig).to receive(:new).and_return(config)
      end

      it "creates a content archive and enqueues ArchiveContentJob" do
        link = nil

        expect {
          link = create(:link)
        }.to change(ContentArchive, :count).by(1)

        expect(ArchiveContentJob).to have_been_enqueued.with(link_id: link.id)
        expect(Rails.logger).to have_received(:info)
          .with("ContentArchive #{link.content_archive.id} created and job enqueued for Link #{link.id}")
      end
    end

    context "when archival is disabled" do
      let(:config) { instance_double(ContentArchiveConfig, enabled: false) }

      before do
        allow(ContentArchiveConfig).to receive(:new).and_return(config)
      end

      it "does not create a content archive or enqueue a job" do
        expect {
          create(:link)
        }.not_to change(ContentArchive, :count)

        expect(ArchiveContentJob).not_to have_been_enqueued
        expect(Rails.logger).not_to have_received(:info)
      end
    end

    context "when archive creation raises an error" do
      let(:config) { instance_double(ContentArchiveConfig, enabled: true) }

      before do
        allow(ContentArchiveConfig).to receive(:new).and_return(config)
        allow(ContentArchive).to receive(:create!).and_raise(StandardError, "boom")
      end

      it "logs the error without raising" do
        expect {
          create(:link)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error)
          .with(a_string_including("Failed to create ContentArchive for Link"))
        expect(ArchiveContentJob).not_to have_been_enqueued
      end
    end
  end

  describe "tag assignment" do
    let(:link) { create(:link) }

    describe "using @tag_names virtual attribute" do
      it "assigns tags from tag names on save" do
        link.tag_names = ["Ruby", "Rails", "Programming"]
        link.save!

        expect(link.tags.pluck(:name)).to match_array(["Ruby", "Rails", "Programming"])
      end

      it "creates new tags if they don't exist" do
        expect {
          link.tag_names = ["NewTag1", "NewTag2"]
          link.save!
        }.to change(Tag, :count).by(2)

        expect(Tag.find_by(name: "NewTag1")).to be_present
        expect(Tag.find_by(name: "NewTag2")).to be_present
      end

      it "uses existing tags if they already exist" do
        existing_tag = create(:tag, name: "Ruby")

        expect {
          link.tag_names = ["Ruby", "NewTag"]
          link.save!
        }.to change(Tag, :count).by(1)

        expect(link.tags).to include(existing_tag)
      end

      it "replaces existing tags with new set" do
        old_tags = create_list(:tag, 2)
        link.tags = old_tags
        link.save!

        link.tag_names = ["NewTag1", "NewTag2"]
        link.save!

        expect(link.tags.pluck(:name)).to match_array(["NewTag1", "NewTag2"])
        old_tags.each do |tag|
          expect(link.tags).not_to include(tag)
        end
      end

      it "clears all tags when given empty array" do
        link.tags << create_list(:tag, 3)
        link.save!

        link.tag_names = []
        link.save!

        expect(link.tags).to be_empty
      end

      it "normalizes tag names (strips whitespace, removes blanks, uniq)" do
        link.tag_names = ["  Ruby  ", "Rails", "  ", "Ruby", "Rails"]
        link.save!

        expect(link.tags.pluck(:name)).to match_array(["Ruby", "Rails"])
      end

      it "clears @tag_names after processing" do
        link.tag_names = ["Ruby"]
        link.save!

        expect(link.instance_variable_get(:@tag_names)).to be_nil
      end

      it "does not trigger callback when @tag_names is nil (not set)" do
        # Create link with tags
        link.tags << create(:tag, name: "Ruby")
        link.save!

        # Update link without setting @tag_names
        link.note = "Updated note"
        link.save!

        # Tags should remain unchanged
        expect(link.tags.pluck(:name)).to eq(["Ruby"])
      end
    end

    describe "#assign_tags (private method)" do
      it "can be called via send for internal testing" do
        link.send(:assign_tags, ["Ruby", "Rails"])

        expect(link.tags.pluck(:name)).to match_array(["Ruby", "Rails"])
      end
    end
  end

  describe "scopes" do
    describe ".sorted_by_tag_count" do
      let!(:link_with_3_tags) { create(:link).tap { |l| l.tags << create_list(:tag, 3) } }
      let!(:link_with_1_tag) { create(:link).tap { |l| l.tags << create(:tag) } }
      let!(:link_with_0_tags) { create(:link) }

      it "sorts by tag count ascending" do
        results = Link.sorted_by_tag_count(:asc)
        expect(results.to_a).to eq([link_with_0_tags, link_with_1_tag, link_with_3_tags])
      end

      it "sorts by tag count descending" do
        results = Link.sorted_by_tag_count(:desc)
        expect(results.to_a).to eq([link_with_3_tags, link_with_1_tag, link_with_0_tags])
      end

      it "raises error for invalid direction" do
        expect {
          Link.sorted_by_tag_count(:invalid)
        }.to raise_error(ArgumentError, /Invalid sort direction/)
      end
    end
  end
end
