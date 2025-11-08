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
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:submitted_url) }
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
end
