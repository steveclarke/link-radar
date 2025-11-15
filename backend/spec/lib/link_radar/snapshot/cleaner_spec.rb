# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::Snapshot::Cleaner do
  describe "#call" do
    let(:exports_dir) { Rails.root.join("tmp/test_exports") }
    let(:imports_dir) { Rails.root.join("tmp/test_imports") }
    let(:tmp_dir) { Rails.root.join("tmp/test_tmp") }

    before do
      # Create test directories
      FileUtils.mkdir_p(exports_dir)
      FileUtils.mkdir_p(imports_dir)
      FileUtils.mkdir_p(tmp_dir)

      # Override config for tests
      allow(CoreConfig).to receive(:snapshot_exports_dir)
        .and_return("tmp/test_exports")
      allow(CoreConfig).to receive(:snapshot_imports_dir)
        .and_return("tmp/test_imports")
      allow(CoreConfig).to receive(:snapshot_tmp_dir)
        .and_return("tmp/test_tmp")
      allow(CoreConfig).to receive(:snapshot_exports_retention_days)
        .and_return(30)
      allow(CoreConfig).to receive(:snapshot_imports_retention_days)
        .and_return(30)
      allow(CoreConfig).to receive(:snapshot_tmp_retention_days)
        .and_return(7)
    end

    after do
      # Cleanup test directories
      FileUtils.rm_rf(exports_dir)
      FileUtils.rm_rf(imports_dir)
      FileUtils.rm_rf(tmp_dir)
    end

    it "deletes files older than retention period" do
      # Create old file (40 days old)
      old_file = exports_dir.join("old.json")
      FileUtils.touch(old_file)
      File.utime(40.days.ago.to_time, 40.days.ago.to_time, old_file)

      # Create recent file (10 days old)
      recent_file = exports_dir.join("recent.json")
      FileUtils.touch(recent_file)
      File.utime(10.days.ago.to_time, 10.days.ago.to_time, recent_file)

      result = described_class.new.call

      expect(result).to be_success
      expect(result.data[:exports_deleted]).to eq(1)
      expect(File.exist?(old_file)).to be false
      expect(File.exist?(recent_file)).to be true
    end

    it "preserves .keep files" do
      keep_file = exports_dir.join(".keep")
      FileUtils.touch(keep_file)
      File.utime(100.days.ago.to_time, 100.days.ago.to_time, keep_file)

      result = described_class.new.call

      expect(result).to be_success
      expect(File.exist?(keep_file)).to be true
    end

    it "cleans up all three directories" do
      # Create old files in each directory
      old_export = exports_dir.join("old-export.json")
      FileUtils.touch(old_export)
      File.utime(40.days.ago.to_time, 40.days.ago.to_time, old_export)

      old_import = imports_dir.join("old-import.json")
      FileUtils.touch(old_import)
      File.utime(40.days.ago.to_time, 40.days.ago.to_time, old_import)

      old_tmp = tmp_dir.join("old-tmp.json")
      FileUtils.touch(old_tmp)
      File.utime(10.days.ago.to_time, 10.days.ago.to_time, old_tmp)

      result = described_class.new.call

      expect(result).to be_success
      expect(result.data[:exports_deleted]).to eq(1)
      expect(result.data[:imports_deleted]).to eq(1)
      expect(result.data[:tmp_deleted]).to eq(1)
    end

    it "skips directories" do
      subdir = exports_dir.join("subdir")
      FileUtils.mkdir_p(subdir)
      File.utime(100.days.ago.to_time, 100.days.ago.to_time, subdir)

      result = described_class.new.call

      expect(result).to be_success
      expect(File.directory?(subdir)).to be true
    end

    it "returns zero counts for non-existent directories" do
      FileUtils.rm_rf(imports_dir)

      result = described_class.new.call

      expect(result).to be_success
      expect(result.data[:imports_deleted]).to eq(0)
    end
  end
end
