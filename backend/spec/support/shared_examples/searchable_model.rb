# frozen_string_literal: true

# Shared examples for testing models that include the Searchable concern.
#
# This provides a clean, user-guided approach where you explicitly set up the
# test data and specify what search terms should be found. The focus is on
# testing behavior, not implementation details.
#
# @example Basic usage
#   it_behaves_like "searchable model", {
#     search_content_class: SearchContent::Link,
#     setup: ->(record) {
#       record.update!(title: "Ruby Programming", note: "Great resource")
#       ruby_tag = create(:tag, name: "Ruby")
#       record.tags << ruby_tag
#
#       ["Ruby", "Programming", "Great", "resource"]
#     }
#   }
#
# @example Simple field-only model
#   it_behaves_like "searchable model", {
#     search_content_class: SearchContent::Tag,
#     setup: ->(record) {
#       record.update!(name: "Ruby", description: "Programming language")
#       ["Ruby", "Programming", "language"]
#     }
#   }
RSpec.shared_examples "searchable model" do |options|
  # Validate required parameters upfront
  if !options[:search_content_class]
    raise ArgumentError, "search_content_class must be specified"
  end

  if !options[:setup]
    raise ArgumentError, "setup block must be specified"
  end

  let(:search_content_class) { options[:search_content_class] }
  let(:setup_block) { options[:setup] }
  let(:model_factory) { described_class.model_name.param_key.to_sym }

  describe "search configuration" do
    it "has proper SearchContent class wired" do
      expect(described_class).to respond_to(:search)
    end

    it "search returns ActiveRecord::Relation" do
      results = described_class.search("test")
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "includes the Searchable concern" do
      expect(described_class).to include(Searchable)
    end
  end

  describe "searchable content" do
    it "finds records by expected search terms" do
      record = create(model_factory)
      expected_terms = instance_exec(record, &setup_block)

      record.reload
      # Ensure projection is current for reliable search testing
      record.rebuild_search_projection if record.respond_to?(:rebuild_search_projection)

      # Test each expected term can find the record
      expected_terms.each do |term|
        results = described_class.search(term)
        expect(results).to include(record), "Expected search for '#{term}' to find the record"
      end
    end

    it "search_projection contains projected content" do
      record = create(model_factory)
      instance_exec(record, &setup_block)

      record.reload
      record.rebuild_search_projection if record.respond_to?(:rebuild_search_projection)

      # For models with search_projection, verify it's populated
      if record.respond_to?(:search_projection)
        expect(record.search_projection).to be_a(String)
        # Projection should be present if model has projection logic
        search_content_class.new(record)
        if search_content_class.projection
          expect(record.search_projection).to be_present
        end
      end
    end

    it "handles case insensitive search" do
      record = create(model_factory)
      expected_terms = instance_exec(record, &setup_block)

      record.reload
      record.rebuild_search_projection if record.respond_to?(:rebuild_search_projection)

      # Test case insensitive search with first term
      if expected_terms.any?
        term = expected_terms.first
        results = described_class.search(term.upcase)
        expect(results).to include(record), "Expected case insensitive search for '#{term.upcase}' to find the record"
      end
    end

    it "handles prefix search" do
      record = create(model_factory)
      expected_terms = instance_exec(record, &setup_block)

      record.reload
      record.rebuild_search_projection if record.respond_to?(:rebuild_search_projection)

      # Test prefix search with first term (if long enough)
      if expected_terms.any? && expected_terms.first.length > 3
        term = expected_terms.first
        prefix = term[0, 3] # First 3 characters
        results = described_class.search(prefix)
        expect(results).to include(record), "Expected prefix search for '#{prefix}' to find the record"
      end
    end
  end

  describe "projection rebuilding" do
    it "can rebuild search_projection manually" do
      record = create(model_factory)
      instance_exec(record, &setup_block)

      record.reload

      # Should be able to rebuild projection
      if record.respond_to?(:rebuild_search_projection)
        record.rebuild_search_projection

        # Verify projection is populated for models with projection logic
        if search_content_class.projection
          expect(record.search_projection).to be_present
        end
      end
    end
  end

  describe "search edge cases" do
    it "returns empty result for non-matching terms" do
      # Create some records
      3.times do
        create(model_factory)
      end

      # Search with a term that shouldn't match anything
      results = described_class.search("ThisShouldMatchNothing123XYZ")

      # Verify empty results
      expect(results).to be_empty
    end

    it "handles nil search terms gracefully" do
      expect { described_class.search(nil) }.not_to raise_error
    end

    it "handles blank search terms gracefully" do
      expect { described_class.search("") }.not_to raise_error
      expect { described_class.search("   ") }.not_to raise_error
    end
  end
end
