# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupSnapshotsJob do
  describe "#perform" do
    it "calls cleaner and logs success" do
      result = LinkRadar::Result.success(
        exports_deleted: 5,
        imports_deleted: 3,
        tmp_deleted: 12
      )

      cleaner = instance_double(LinkRadar::Snapshot::Cleaner)
      allow(LinkRadar::Snapshot::Cleaner).to receive(:new)
        .and_return(cleaner)
      allow(cleaner).to receive(:call).and_return(result)

      expect(Rails.logger).to receive(:info)
        .with(/Snapshot cleanup completed: 5 exports, 3 imports, 12 temp/)

      described_class.new.perform
    end

    it "logs errors on failure" do
      result = LinkRadar::Result.failure("Disk full")

      cleaner = instance_double(LinkRadar::Snapshot::Cleaner)
      allow(LinkRadar::Snapshot::Cleaner).to receive(:new)
        .and_return(cleaner)
      allow(cleaner).to receive(:call).and_return(result)

      expect(Rails.logger).to receive(:error)
        .with(/Snapshot cleanup failed: Disk full/)

      described_class.new.perform
    end
  end
end
