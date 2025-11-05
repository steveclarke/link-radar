# frozen_string_literal: true

module SearchContent
  # Search configuration for Link model with projection support
  #
  # Links are searchable across their core fields (note, url)
  # and associated data (tag names). Uses a hybrid search approach:
  # - Trigram for fuzzy matching and partial terms
  # - TSearch for word-based content search with prefix matching
  #
  # Note: Content and title are now stored in ContentArchive model
  #
  # @example Usage in Link model
  #   class Link < ApplicationRecord
  #     include Searchable
  #     searchable_with SearchContent::Link, project: true
  #   end
  #
  # @example Searching links
  #   Link.search("ruby programming")  # Finds links by note or tags
  #   Link.search("708")                # Finds links tagged with partial matches
  #   Link.search("rails")              # Finds links by note or tags
  class Link < SearchContent::Base
    SEARCH_FIELDS = {
      note: "A",             # Highest priority - user notes
      url: "B",              # Medium priority - URL
      search_projection: nil # No weight - cached associated data (tags)
    }

    def self.search_fields = SEARCH_FIELDS

    # Uses hybrid search approach for best results:
    # - Trigram handles fuzzy matching and partial terms
    # - TSearch handles word-based content search
    #
    # @return [Hash] pg_search using configuration
    def self.using
      {
        trigram: {word_similarity: true, threshold: 0.25},
        tsearch: {prefix: true, any_word: true, dictionary: "english"}
      }
    end

    # Additional pg_search options for accent insensitivity and ranking
    #
    # @return [Hash] pg_search scope options
    def self.scope_options
      {
        ignoring: :accents,
        ranked_by: ":tsearch * 0.6 + :trigram * 0.4"
      }
    end

    # Builds search projection from associated tag names
    #
    # This denormalizes tag names into the search_projection column
    # for efficient searching without joins.
    projection do
      assoc :tags do |tag|
        [tag.name, tag.slug]
      end
    end
  end
end
