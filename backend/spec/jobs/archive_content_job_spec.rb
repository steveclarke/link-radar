# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArchiveContentJob do
  include ActiveJob::TestHelper

  let!(:link) { create(:link) }
  let(:archive) { link.content_archive }
  let(:archiver) { instance_double(LinkRadar::ContentArchiving::Archiver) }
  let(:captured_archives) { [] }

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
    allow(LinkRadar::ContentArchiving::Archiver).to receive(:new) do |args|
      captured_archives << args.fetch(:archive)
      archiver
    end
  end

  describe "#perform" do
    context "with successful archival" do
      before do
        allow(archiver).to receive(:call) do
          archive_record = captured_archives.last
          archive_record.transition_to!(:processing)
          archive_record.transition_to!(:completed)
          LinkRadar::Result.success(archive_record)
        end
      end

      it "finds Link and ContentArchive by link_id" do
        expect(Link).to receive(:find).with(link.id).and_call_original

        described_class.perform_now(link_id: link.id)
      end

      it "calls Archiver service with archive" do
        described_class.perform_now(link_id: link.id)

        expect(LinkRadar::ContentArchiving::Archiver)
          .to have_received(:new).with(archive: instance_of(ContentArchive))
        expect(archiver).to have_received(:call)
      end

      it "logs completion with archive state" do
        described_class.perform_now(link_id: link.id)

        invoked_archive = captured_archives.last
        expect(Rails.logger).to have_received(:info)
          .with("ContentArchive #{invoked_archive.id} job completed: completed")
      end
    end

    context "with Archiver returning failure Result" do
      let(:failure_result) { LinkRadar::Result.failure("Fetch failed") }

      before do
        allow(archiver).to receive(:call) do
          archive_record = captured_archives.last
          archive_record.transition_to!(:processing)
          archive_record.transition_to!(
            :failed,
            error_reason: "network_error",
            error_message: "Fetch failed"
          )
          failure_result
        end
      end

      it "completes without raising exceptions" do
        expect {
          described_class.perform_now(link_id: link.id)
        }.not_to raise_error
      end

      it "still logs the completion state" do
        described_class.perform_now(link_id: link.id)

        invoked_archive = captured_archives.last
        expect(Rails.logger).to have_received(:info)
          .with("ContentArchive #{invoked_archive.id} job completed: failed")
      end
    end

    context "with missing Link (ActiveRecord::RecordNotFound)" do
      before do
        allow(Link).to receive(:find).with(link.id).and_raise(ActiveRecord::RecordNotFound)
      end

      it "is discarded without retrying" do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(link_id: link.id)
          end
        }.not_to raise_error

        expect(LinkRadar::ContentArchiving::Archiver).not_to have_received(:new)
      end
    end

    context "with missing ContentArchive (ActiveRecord::RecordNotFound)" do
      before do
        allow(Link).to receive(:find).with(link.id).and_return(link)
        allow(link).to receive(:content_archive).and_raise(ActiveRecord::RecordNotFound)
      end

      it "is discarded without retrying" do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(link_id: link.id)
          end
        }.not_to raise_error

        expect(LinkRadar::ContentArchiving::Archiver).not_to have_received(:new)
      end
    end
  end
end
