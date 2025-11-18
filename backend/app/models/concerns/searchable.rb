# frozen_string_literal: true

# Provides full-text search capabilities to ActiveRecord models using PostgreSQL's
# text search functionality via the pg_search gem.
#
# This concern simplifies the setup of searchable models by accepting a content
# builder class that defines search configuration and optionally handles search
# projection caching for performance optimization.
#
# @example Basic usage without projection
#   class Tag < ApplicationRecord
#     include Searchable
#     searchable_with SearchContent::Tag
#   end
#
# @example Usage with search projection caching
#   class Link < ApplicationRecord
#     include Searchable
#     searchable_with SearchContent::Link, project: true
#   end
#
# @see SearchContent::Link
# @see SearchContent::Tag
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    # Configures full-text search for the model using a content builder class.
    #
    # The content builder class must respond to:
    # - `.search_fields` - returns array/hash of fields to search against
    # - `.using` - returns pg_search configuration hash
    # - `.scope_options` (optional) - returns additional pg_search options
    #
    # When `project: true` is specified, the model must have a `search_projection`
    # column to cache search content for performance. This adds callbacks to
    # maintain the projection automatically.
    #
    # @param content_builder_class [Class] builder class that defines search configuration
    # @param project [Boolean] whether to enable search projection caching
    # @return [void]
    # @raise [ArgumentError] if content_builder_class doesn't respond to required methods
    #
    # @example Basic search setup
    #   class Tag < ApplicationRecord
    #     include Searchable
    #     searchable_with SearchContent::Tag
    #   end
    #
    #   # Usage:
    #   Tag.search("ruby")
    #
    # @example With search projection for performance
    #   class Link < ApplicationRecord
    #     include Searchable
    #     searchable_with SearchContent::Link, project: true
    #   end
    #
    #   # The search_projection column will be automatically maintained
    #   Link.search("ruby programming")
    #
    # @see PgSearch::Model
    def searchable_with(content_builder_class, project: false)
      unless content_builder_class.respond_to?(:search_fields) && content_builder_class.respond_to?(:using)
        raise ArgumentError, "builder must respond to .search_fields/.using"
      end

      include PgSearch::Model

      options = {
        against: content_builder_class.search_fields,
        using: content_builder_class.using
      }
      if content_builder_class.respond_to?(:scope_options)
        options.merge!(content_builder_class.scope_options)
      end

      pg_search_scope :search, **options

      if project
        before_save do
          self.search_projection = content_builder_class.new(self).search_projection
        end

        after_touch :rebuild_search_projection

        # Rebuilds the search projection by creating a new content builder instance
        # and updating the search_projection column directly (bypassing callbacks).
        #
        # This method is automatically defined when `project: true` is used with
        # {#searchable_with} and is called via the `after_touch` callback.
        #
        # Since `touch` creates its own transaction and commits immediately,
        # this method runs after the touch transaction has committed.
        #
        # @return [Boolean] result of the database update
        # @example
        #   link.rebuild_search_projection
        #   # Updates search_projection column with fresh content
        define_method :rebuild_search_projection do
          builder = content_builder_class.new(self)
          update_column(:search_projection, builder.search_projection)
        end
      end
    end
  end
end
