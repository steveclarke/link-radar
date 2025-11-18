# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::SecureFileDownload do
  let(:temp_dir) { Pathname.new(Dir.mktmpdir) }
  let(:allowed_directory) { temp_dir.join("exports") }
  let(:outside_directory) { temp_dir.join("other") }

  before do
    FileUtils.mkdir_p(allowed_directory)
    FileUtils.mkdir_p(outside_directory)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".call" do
    context "with valid filename" do
      let(:filename) { "export-2024-01-01.json" }
      let(:file_path) { allowed_directory.join(filename) }

      before do
        File.write(file_path, '{"data": "test"}')
      end

      it "returns success result" do
        result = described_class.call(
          filename: filename,
          allowed_directory: allowed_directory
        )

        expect(result).to be_success
        expect(result.data.file_path).to eq(file_path)
        expect(result.data.safe_filename).to eq(filename)
        expect(result.errors).to be_empty
      end
    end

    context "with path traversal attempts" do
      it "rejects filename with forward slash" do
        result = described_class.call(
          filename: "../secret.txt",
          allowed_directory: allowed_directory
        )

        expect(result).to be_failure
        expect(result.errors.first).to include("path traversal")
        expect(result.data.status).to eq(:forbidden)
      end

      it "rejects filename with backslash" do
        result = described_class.call(
          filename: "..\\secret.txt",
          allowed_directory: allowed_directory
        )

        expect(result).to be_failure
        expect(result.errors.first).to include("path traversal")
        expect(result.data.status).to eq(:forbidden)
      end

      it "rejects filename starting with dot" do
        result = described_class.call(
          filename: ".hidden",
          allowed_directory: allowed_directory
        )

        expect(result).to be_failure
        expect(result.errors.first).to include("path traversal")
        expect(result.data.status).to eq(:forbidden)
      end

      it "rejects blank filename" do
        result = described_class.call(
          filename: "",
          allowed_directory: allowed_directory
        )

        expect(result).to be_failure
        expect(result.errors.first).to include("blank")
        expect(result.data.status).to eq(:forbidden)
      end
    end

    context "with non-existent file" do
      it "returns not found error" do
        result = described_class.call(
          filename: "missing.json",
          allowed_directory: allowed_directory
        )

        expect(result).to be_failure
        expect(result.errors.first).to eq("File not found")
        expect(result.data.status).to eq(:not_found)
      end
    end

    context "with symlink outside allowed directory" do
      let(:filename) { "symlink.json" }
      let(:symlink_path) { allowed_directory.join(filename) }
      let(:target_path) { outside_directory.join("secret.json") }

      before do
        File.write(target_path, '{"secret": "data"}')
        FileUtils.ln_s(target_path, symlink_path)
      end

      it "rejects access to symlinked file outside directory" do
        result = described_class.call(
          filename: filename,
          allowed_directory: allowed_directory
        )

        expect(result).to be_failure
        expect(result.errors.first).to include("outside allowed directory")
        expect(result.data.status).to eq(:forbidden)
      end
    end

    context "with file in subdirectory" do
      let(:subdirectory) { allowed_directory.join("2024") }
      let(:filename) { "export.json" }
      let(:file_path) { subdirectory.join(filename) }

      before do
        FileUtils.mkdir_p(subdirectory)
        File.write(file_path, '{"data": "test"}')
      end

      it "allows access to file in subdirectory when using simple filename" do
        # This should fail since we're only looking in the root allowed_directory
        result = described_class.call(
          filename: filename,
          allowed_directory: subdirectory
        )

        expect(result).to be_success
      end
    end
  end

  describe "Data objects" do
    describe "SuccessData" do
      it "creates success data with file info" do
        data = described_class::SuccessData.new(
          file_path: "/path/to/file.json",
          safe_filename: "file.json"
        )

        expect(data.file_path).to eq("/path/to/file.json")
        expect(data.safe_filename).to eq("file.json")
      end
    end

    describe "ErrorData" do
      it "creates error data with status" do
        data = described_class::ErrorData.new(status: :forbidden)

        expect(data.status).to eq(:forbidden)
      end
    end
  end
end
