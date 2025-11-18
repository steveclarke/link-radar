# frozen_string_literal: true

module SearchContent
  # Search configuration for Tag model
  #
  # Tags are searchable by name and description using full-text search
  # with prefix matching. Uses only TSearch (no trigram) since tags
  # are typically short, well-defined terms.
  #
  # @example Usage in Tag model
  #   class Tag < ApplicationRecord
  #     include Searchable
  #     searchable_with SearchContent::Tag
  #   end
  #
  # @example Searching tags
  #   Tag.search("ruby")        # Finds "Ruby", "Ruby on Rails"
  #   Tag.search("javascript")  # Finds "JavaScript", "JS"
  class Tag < SearchContent::Base
    SEARCH_FIELDS = {
      name: "A",        # Highest priority - tag name
      description: "B"  # Lower priority - tag description
    }

    def self.search_fields = SEARCH_FIELDS

    # Uses TSearch with prefix matching for tag search
    # No trigram needed since tags are well-defined terms
    #
    # @return [Hash] pg_search using configuration
    def self.using
      {
        tsearch: {prefix: true, any_word: true, dictionary: "english"}
      }
    end

    # Additional pg_search options for accent insensitivity
    #
    # @return [Hash] pg_search scope options
    def self.scope_options
      {
        ignoring: :accents
      }
    end
  end
end
