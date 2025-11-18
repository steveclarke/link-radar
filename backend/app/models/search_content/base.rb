# frozen_string_literal: true

# SearchContent::Base provides the foundation for model search configuration and
# search projection building.
#
# This class serves two main purposes:
# 1. **Base class for SearchContent configurations**: Subclasses define search
#    fields, pg_search methods, and projection logic for specific models
# 2. **Projection DSL**: Provides a declarative way to build search_projection
#    content from computed values, associations, and derived tokens
#
# ## Basic Usage
#
# Create a SearchContent class for each searchable model:
#
# ```ruby
# class SearchContent::Link < SearchContent::Base
#   SEARCH_FIELDS = {
#     title: "A",
#     content_text: "B",
#     search_projection: nil
#   }
#
#   def self.search_fields = SEARCH_FIELDS
#   def self.using = { tsearch: { prefix: true, dictionary: "english" } }
#
#   # Optional: Define projection for search_projection column
#   projection do
#     assoc :tags { |tag| tag.name }
#   end
# end
# ```
#
# ## Search Projection DSL
#
# For models that need to search associated data (tags, etc.),
# use the projection DSL to build a denormalized search_projection column:
#
# ```ruby
# projection do
#   # Include computed methods (not DB columns)
#   compute :full_name
#
#   # Include association data
#   assoc :tags do |tag|
#     [tag.name, tag.description]
#   end
#
#   # Use built-in helpers
#   project_emails     # Email addresses
#   project_phones     # Tokenized phone numbers
#
#   # Custom token generation
#   custom do
#     record.title&.upcase&.gsub(/[^A-Z0-9]/, "")
#   end
# end
# ```
#
# The projection DSL automatically handles:
# - Flattening nested arrays
# - Removing blank values
# - Deduplicating tokens
# - Joining into a single searchable string
#
# @see Searchable The concern that wires models to SearchContent classes
# @see SearchContent::Link Example of a complex SearchContent implementation
# @see SearchContent::Tag Example of a simple SearchContent implementation
module SearchContent
  class Base
    # @param record [ApplicationRecord] The model instance being projected
    # @note This is automatically called by the Searchable concern during save callbacks
    #   and search projection rebuilding
    # @see Searchable#searchable_with
    def initialize(record)
      @record = record
    end

    # Defines the projection logic for building search_projection content.
    # This class method stores a block that will be executed in the context
    # of a builder instance when #search_projection is called.
    #
    # @yield The block defining what content to include in search_projection
    # @return [Proc, nil] The stored projection block
    # @example
    #   projection do
    #     compute :display_name
    #     assoc :tags { |tag| tag.name }
    #   end
    def self.projection(&block)
      @projection_block = block if block
      @projection_block
    end

    # Builds the search projection string by executing the projection block
    # and collecting all generated tokens into a single searchable string.
    #
    # @return [String] Space-separated tokens for search_projection column
    # @example
    #   builder = SearchContent::Link.new(link)
    #   builder.search_projection
    #   # => "Ruby Programming ruby-lang programming-languages"
    def search_projection
      block = self.class.projection
      return "" unless block

      @__projection_parts = []
      instance_exec(&block)
      parts = @__projection_parts
      Array(parts).flatten.compact_blank.uniq.join(" ")
    end

    # ============================= DSL Methods =============================
    #
    # These methods are used within projection blocks to build search content.

    # Includes computed method values in the search projection.
    # Use this for methods that derive values from existing data but are not
    # stored database columns.
    #
    # @param name [Symbol] Method name to call on the record
    # @return [String, Array<String>, nil] The computed value(s)
    # @raise [ArgumentError] If the method name matches a database column
    # @example
    #   projection do
    #     compute :display_name     # Calls link.display_name
    #   end
    def compute(name)
      # Guard: computed values must NOT be direct DB columns
      if record.class.column_names.include?(name.to_s)
        raise ArgumentError, "compute(:#{name}) is for non-DB methods; put DB columns in SEARCH_FIELDS"
      end

      value = safe_send(record, name)
      append_parts(value)
      value
    end

    # Includes multiple computed method values in the search projection.
    # Convenience method for calling compute on multiple methods.
    #
    # @param names [Array<Symbol>] Method names to call on the record
    # @return [Array<String>] Array of computed values
    # @example
    #   projection do
    #     compute_many :display_name, :formatted_url
    #   end
    def compute_many(*names)
      values = names.map { |n| compute(n) }
      append_parts(values)
      values
    end

    # Iterates over an association and extracts searchable content from each
    # associated record using the provided block.
    #
    # @param name [Symbol] Association name to iterate over
    # @yield [item] Block called for each associated record
    # @yieldparam item [ApplicationRecord] The associated record
    # @yieldreturn [String, Array<String>] Searchable content from the record
    # @return [Array<String>, nil] Array of extracted tokens, nil if no items
    # @example
    #   projection do
    #     assoc :tags do |tag|
    #       [tag.name, tag.slug]
    #     end
    #   end
    def assoc(name, &block)
      items = Array(record.public_send(name))
      return nil if items.empty?

      tokens = items.map { |item| instance_exec(item, &block) }
      append_parts(tokens)
      tokens
    end

    # Provides arbitrary token generation using a custom block.
    # Use this for complex logic that doesn't fit the other DSL methods.
    #
    # @yield Custom logic block executed in the builder context
    # @yieldreturn [String, Array<String>] Custom tokens to include
    # @return [Array<String>, String, nil] Generated tokens
    # @example
    #   projection do
    #     custom do
    #       # Generate normalized variants
    #       title = record.title.to_s.upcase
    #       [title, title.gsub(/[^A-Z0-9]/, "")]
    #     end
    #   end
    def custom(&block)
      tokens = instance_exec(&block)
      append_parts(tokens)
      tokens
    end

    # ========================= Built-in Projection Helpers =================
    #
    # These convenience methods handle common projection scenarios.

    # Projects email addresses into the search projection.
    # Allows searching by email addresses associated with the record.
    #
    # @param assoc [Symbol] Association name to iterate over (default: :email_addresses)
    # @param attr [Symbol] Attribute to read from each email record (default: :email)
    # @return [Array<String>, nil] Email tokens, nil if no emails
    # @example
    #   projection do
    #     project_emails                              # Uses email_addresses.email
    #     project_emails(assoc: :contacts, attr: :address) # Uses contacts.address
    #   end
    def project_emails(assoc: :email_addresses, attr: :email)
      self.assoc(assoc) { |e| e.public_send(attr) }
    end

    # Projects tokenized phone numbers into the search projection.
    # Uses phone_tokens to create multiple searchable variants of each number.
    #
    # @param assoc [Symbol] Association name to iterate over (default: :phone_numbers)
    # @param attr [Symbol] Attribute to read from each phone record (default: :number)
    # @return [Array<String>, nil] Phone tokens, nil if no phone numbers
    # @example
    #   projection do
    #     project_phones                               # Uses phone_numbers.number
    #     project_phones(assoc: :contacts, attr: :phone) # Uses contacts.phone
    #   end
    def project_phones(assoc: :phone_numbers, attr: :number)
      self.assoc(assoc) { |p| phone_tokens(p.public_send(attr)) }
    end

    # Tokenizes phone numbers for optimal search performance.
    #
    # Creates multiple searchable variants of a phone number to handle different
    # search patterns. This ensures excellent findability for area codes,
    # exchanges, and number parts.
    #
    # This method is public because:
    # 1. The tokenization algorithm is complex and needs thorough direct testing
    # 2. Developers may want to use it in custom projection blocks
    # 3. It's a reusable utility for phone number search optimization
    #
    # @param raw [String] Raw phone number string
    # @return [Array<String>, nil] Array of phone tokens, nil if no digits
    # @example Phone number tokenization
    #   phone_tokens("709-673-5555")
    #   # => ["7096735555", "709 673 5555", "709", "673", "5555"]
    #
    #   # Search benefits:
    #   Link.search("709")   # Finds links with 709 area code (perfect ranking)
    #   Link.search("673")   # Finds links with 673 exchange (perfect ranking)
    #   Link.search("5555")  # Finds numbers ending in 5555 (perfect ranking)
    #
    # @example Usage in custom projection
    #   projection do
    #     custom do
    #       # Custom phone handling with special formatting
    #       phones = record.metadata["phone_numbers"]
    #       phones.flat_map { |phone| phone_tokens(phone) }
    #     end
    #   end
    def phone_tokens(raw)
      digits = raw.to_s.gsub(/\D/, "")
      return nil if digits.empty?

      formatted = digits.gsub(/(\d{3})(\d{3})(\d{4})/, "\\1 \\2 \\3")
      last4 = digits[-4, 4]
      mid3 = (digits.length >= 7) ? digits[-7, 3] : nil
      area3 = (digits.length >= 10) ? digits[-10, 3] : nil
      [digits, formatted, area3, mid3, last4]
    end

    # ========================= Required Subclass Methods ====================
    #
    # These methods must be implemented by subclasses to define search behavior.

    # Defines the fields/columns to search against for pg_search.
    # Must return a hash mapping field names to pg_search weights or an array.
    #
    # @return [Hash<Symbol, String>, Array<Symbol>] Search field configuration
    # @raise [NotImplementedError] When not implemented by subclass
    # @example
    #   def self.search_fields
    #     { title: "A", content_text: "B", search_projection: nil }
    #   end
    def self.search_fields
      raise NotImplementedError, "#{self} must implement .search_fields"
    end

    # Defines the pg_search configuration for the search method.
    # Must return a hash with pg_search options like :tsearch, :trigram, etc.
    #
    # @return [Hash] pg_search using configuration
    # @raise [NotImplementedError] When not implemented by subclass
    # @example
    #   def self.using
    #     { tsearch: { prefix: true, dictionary: "english" } }
    #   end
    def self.using
      raise NotImplementedError, "#{self} must implement .using"
    end

    private

    # @return [ApplicationRecord] The model instance being projected
    attr_reader :record

    # Safely calls a method on an object and normalizes the return value.
    # Handles cases where the method might not exist or return nil.
    #
    # @param obj [Object] Object to call the method on
    # @param name [Symbol] Method name to call
    # @return [String, Array<String>, nil] Normalized value or nil
    def safe_send(obj, name)
      value = obj.respond_to?(name) ? obj.public_send(name) : nil
      value.is_a?(Array) ? value : value.to_s.presence
    end

    # Appends values to the internal projection parts array.
    # Handles both single values and arrays by flattening appropriately.
    #
    # @param values [String, Array<String>, nil] Values to append
    # @return [void]
    def append_parts(values)
      return if values.nil?

      @__projection_parts ||= []
      if values.is_a?(Array)
        @__projection_parts.concat(values)
      else
        @__projection_parts << values
      end
    end
  end
end
