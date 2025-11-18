# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkRadar::Snapshot::Importer do
  # Use a temporary directory for test import files
  let(:temp_import_dir) { Rails.root.join("tmp/test_imports") }
  let(:test_file_path) { temp_import_dir.join("test-import.json") }

  before do
    # Ensure temp directory exists and is clean
    FileUtils.rm_rf(temp_import_dir)
    FileUtils.mkdir_p(temp_import_dir)
  end

  after do
    # Clean up temp directory after each test
    FileUtils.rm_rf(temp_import_dir) if temp_import_dir.exist?
  end

  # Helper method to create a valid import JSON file
  def create_import_file(data)
    File.write(test_file_path, JSON.pretty_generate(data))
    test_file_path
  end

  # Helper method to create valid import data structure
  def valid_import_data(links_data)
    {
      version: "1.0",
      exported_at: Time.current.utc.iso8601,
      metadata: {
        link_count: links_data.size,
        tag_count: links_data.flat_map { |l| l[:tags] }.uniq.size
      },
      links: links_data
    }
  end

  describe "#initialize" do
    it "accepts skip mode (default)" do
      importer = described_class.new(file_path: test_file_path.to_s)
      expect(importer).to be_a(described_class)
    end

    it "accepts update mode" do
      importer = described_class.new(file_path: test_file_path.to_s, mode: :update)
      expect(importer).to be_a(described_class)
    end

    it "raises error for invalid mode" do
      expect {
        described_class.new(file_path: test_file_path.to_s, mode: :invalid)
      }.to raise_error(ArgumentError, /Invalid mode/)
    end
  end

  describe "#call" do
    context "with valid data in skip mode" do
      let(:import_data) do
        valid_import_data([
          {
            url: "https://example.com",
            note: "Example site",
            created_at: 2.days.ago.utc.iso8601,
            tags: [
              {name: "ruby", description: "Ruby programming language"},
              {name: "web", description: nil}
            ]
          },
          {
            url: "https://rails.org",
            note: "Rails framework",
            created_at: 1.day.ago.utc.iso8601,
            tags: [
              {name: "ruby", description: "Ruby programming language"},
              {name: "rails", description: "Web framework"}
            ]
          }
        ])
      end

      let(:file_path) { create_import_file(import_data) }

      it "imports all links and tags with correct statistics" do
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success
        expect(result.data[:links_imported]).to eq(2)
        expect(result.data[:links_skipped]).to eq(0)
        expect(result.data[:tags_created]).to eq(3) # ruby, web, rails
        expect(result.data[:tags_reused]).to eq(1) # ruby reused once

        # Verify links created in database
        expect(Link.count).to eq(2)
        expect(Tag.count).to eq(3)
      end

      it "preserves imported created_at timestamps" do
        expected_timestamp = 2.days.ago.utc
        import_data[:links][0][:created_at] = expected_timestamp.iso8601

        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        link = Link.find_by(url: "https://example.com/") # normalized with trailing slash
        expect(link.created_at.to_i).to eq(expected_timestamp.to_i)
      end

      it "assigns tags correctly to links" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        link1 = Link.find_by(url: "https://example.com/")
        expect(link1.tags.pluck(:name)).to match_array(["ruby", "web"])

        link2 = Link.find_by(url: "https://rails.org/")
        expect(link2.tags.pluck(:name)).to match_array(["ruby", "rails"])
      end

      it "normalizes URLs correctly" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        # URLs should be normalized with trailing slashes
        expect(Link.find_by(url: "https://example.com/")).to be_present
        expect(Link.find_by(url: "https://rails.org/")).to be_present
      end
    end

    context "with duplicate URLs in skip mode" do
      let!(:existing_link) do
        create(:link, url: "https://example.com", note: "Original note").tap do |link|
          link.tag_names = ["original"]
          link.save!
        end
      end

      let(:import_data) do
        valid_import_data([
          {
            url: "https://example.com",
            note: "Updated note",
            created_at: 1.day.ago.utc.iso8601,
            tags: [{name: "imported", description: nil}]
          },
          {
            url: "https://new-link.com",
            note: "New link",
            created_at: 1.day.ago.utc.iso8601,
            tags: []
          }
        ])
      end

      it "skips duplicates and preserves existing data" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success
        expect(result.data[:links_imported]).to eq(1) # Only new link
        expect(result.data[:links_skipped]).to eq(1) # Existing link skipped

        # Verify existing link unchanged
        existing_link.reload
        expect(existing_link.note).to eq("Original note")
        expect(existing_link.tags.pluck(:name)).to eq(["original"])
      end

      it "imports only new links" do
        initial_count = Link.count
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success
        expect(Link.count).to eq(initial_count + 1)
        expect(Link.find_by(url: "https://new-link.com/")).to be_present
      end
    end

    context "with duplicate URLs in update mode" do
      let!(:existing_link) do
        create(:link, url: "https://example.com", note: "Original note").tap do |link|
          link.tag_names = ["original"]
          link.save!
        end
      end

      let(:original_created_at) { existing_link.created_at }

      let(:import_data) do
        valid_import_data([
          {
            url: "https://example.com",
            note: "Updated note",
            created_at: 2.days.ago.utc.iso8601,
            tags: [
              {name: "imported", description: "New tag"},
              {name: "updated", description: nil}
            ]
          }
        ])
      end

      it "updates link data but preserves original created_at" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :update)
        result = importer.call

        expect(result).to be_success
        expect(result.data[:links_imported]).to eq(1)
        expect(result.data[:links_skipped]).to eq(0)

        existing_link.reload
        expect(existing_link.note).to eq("Updated note")
        expect(existing_link.created_at.to_i).to eq(original_created_at.to_i) # Preserved!
      end

      it "replaces tags completely" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :update)
        result = importer.call

        expect(result).to be_success

        existing_link.reload
        expect(existing_link.tags.pluck(:name)).to match_array(["imported", "updated"])
        expect(existing_link.tags.pluck(:name)).not_to include("original")
      end
    end

    context "with new links in update mode" do
      let(:import_data) do
        valid_import_data([
          {
            url: "https://new-link.com",
            note: "New link",
            created_at: 2.days.ago.utc.iso8601,
            tags: []
          }
        ])
      end

      it "creates new link with imported created_at" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :update)
        result = importer.call

        expect(result).to be_success

        link = Link.find_by(url: "https://new-link.com/")
        expect(link).to be_present
        expect(link.created_at.to_i).to eq(Time.zone.parse(import_data[:links][0][:created_at]).to_i)
      end
    end

    context "with case-insensitive tag matching" do
      let!(:existing_tag) { Tag.create!(name: "Ruby", description: "Programming language") }

      let(:import_data) do
        valid_import_data([
          {
            url: "https://example.com",
            note: "Test",
            created_at: 1.day.ago.utc.iso8601,
            tags: [{name: "ruby", description: "Different case"}]
          }
        ])
      end

      it "reuses existing tag regardless of case" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success
        expect(result.data[:tags_created]).to eq(0)
        expect(result.data[:tags_reused]).to eq(1)
        expect(Tag.count).to eq(1) # No new tag created
      end

      it "preserves original tag capitalization" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        tag = Tag.first
        expect(tag.name).to eq("Ruby") # Original capitalization preserved
      end

      it "updates blank description from import" do
        existing_tag.update!(description: nil)

        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        existing_tag.reload
        expect(existing_tag.description).to eq("Different case")
      end

      it "does not overwrite existing description" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        existing_tag.reload
        expect(existing_tag.description).to eq("Programming language") # Original preserved
      end
    end

    context "with invalid data" do
      it "returns failure for invalid JSON" do
        File.write(test_file_path, "{ invalid json")

        importer = described_class.new(file_path: test_file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_failure
        expect(result.errors.first).to include("Invalid JSON format")
      end

      it "returns failure for missing file" do
        importer = described_class.new(file_path: "nonexistent.json", mode: :skip)
        result = importer.call

        expect(result).to be_failure
        expect(result.errors.first).to include("Import failed")
      end

      it "returns failure for unsupported version" do
        invalid_data = valid_import_data([])
        invalid_data[:version] = "2.0"

        file_path = create_import_file(invalid_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_failure
        expect(result.errors.first).to include("Unsupported version: 2.0")
      end

      it "returns failure for invalid structure (links not an array)" do
        invalid_data = {
          version: "1.0",
          exported_at: Time.current.utc.iso8601,
          metadata: {link_count: 0, tag_count: 0},
          links: "not an array"
        }

        file_path = create_import_file(invalid_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_failure
        expect(result.errors.first).to include("'links' must be an array")
      end
    end

    context "with transaction rollback" do
      let(:import_data) do
        valid_import_data([
          {
            url: "https://valid-link.com",
            note: "This is valid",
            created_at: 1.day.ago.utc.iso8601,
            tags: []
          },
          {
            url: "", # Empty URL will fail validation
            note: "This is invalid",
            created_at: 1.day.ago.utc.iso8601,
            tags: []
          }
        ])
      end

      it "rolls back all changes on error (no partial imports)" do
        file_path = create_import_file(import_data)
        initial_link_count = Link.count
        initial_tag_count = Tag.count

        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_failure

        # Verify no links were created (transaction rolled back)
        expect(Link.count).to eq(initial_link_count)
        expect(Tag.count).to eq(initial_tag_count)
        expect(Link.find_by(url: "https://valid-link.com/")).to be_nil
      end

      it "returns error message describing the failure" do
        file_path = create_import_file(import_data)

        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_failure
        expect(result.errors.first).to include("Import failed")
      end
    end

    context "with empty links array" do
      let(:import_data) { valid_import_data([]) }

      it "succeeds with zero imports" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success
        expect(result.data[:links_imported]).to eq(0)
        expect(result.data[:links_skipped]).to eq(0)
        expect(result.data[:tags_created]).to eq(0)
        expect(result.data[:tags_reused]).to eq(0)
      end
    end

    context "with links without tags" do
      let(:import_data) do
        valid_import_data([
          {
            url: "https://example.com",
            note: "No tags",
            created_at: 1.day.ago.utc.iso8601,
            tags: []
          }
        ])
      end

      it "imports link successfully without tags" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success
        expect(result.data[:links_imported]).to eq(1)
        expect(result.data[:tags_created]).to eq(0)

        link = Link.find_by(url: "https://example.com/")
        expect(link.tags).to be_empty
      end
    end

    context "with URL normalization edge cases" do
      let(:import_data) do
        valid_import_data([
          {
            url: "example.com", # No scheme
            note: "Missing scheme",
            created_at: 1.day.ago.utc.iso8601,
            tags: []
          },
          {
            url: "HTTPS://EXAMPLE.COM/PATH", # Uppercase
            note: "Uppercase URL",
            created_at: 1.day.ago.utc.iso8601,
            tags: []
          }
        ])
      end

      it "normalizes URLs correctly" do
        file_path = create_import_file(import_data)
        importer = described_class.new(file_path: file_path.to_s, mode: :skip)
        result = importer.call

        expect(result).to be_success

        # Missing scheme gets HTTPS added
        expect(Link.find_by(url: "https://example.com/")).to be_present

        # Uppercase normalized to lowercase
        expect(Link.find_by(url: "https://example.com/PATH")).to be_present
      end
    end
  end
end
