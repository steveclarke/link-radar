# Represents a tag that can be applied to links for organization and discovery
#
# == Schema Information
#
# Table name: tags
#
#  id           :uuid             not null, primary key
#  description  :string(500)
#  last_used_at :datetime
#  name         :string(100)      not null
#  slug         :string(100)      not null
#  usage_count  :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_tags_on_name  (name)
#  index_tags_on_slug  (slug) UNIQUE
#
class Tag < ApplicationRecord
  include Saltbox::SortByColumns::Model
  include Searchable

  # Search configuration
  searchable_with SearchContent::Tag

  # Associations
  has_many :link_tags, dependent: :destroy
  has_many :links, through: :link_tags

  # Configure sortable columns
  sort_by_columns :name, :usage_count, :last_used_at, :created_at

  # Validations
  validates :name, presence: true, length: {maximum: 100}
  validates :slug, presence: true, uniqueness: true, length: {maximum: 100}
  validates :description, length: {maximum: 500}, allow_blank: true
  validates :usage_count, presence: true

  # Callbacks
  before_validation :generate_slug, if: -> { name_changed? }

  # Scopes
  scope :alphabetical, -> { order(:name) }
  scope :by_usage, -> { order(usage_count: :desc, name: :asc) }
  scope :recently_used, -> { order(last_used_at: :desc, name: :asc) }
  # Note: .search scope is provided by Searchable concern via pg_search

  # @param query [String] search term for tag name
  # @return [ActiveRecord::Relation<Tag>] matching tags
  # @example
  #   Tag.autocomplete("java") # => [<Tag name="JavaScript">, ...]
  def self.autocomplete(query)
    return alphabetical if query.blank?

    search(query).by_usage.limit(20)
  end

  # Increment the usage count for this tag
  # @return [Boolean] true if successful
  def increment_usage!
    increment!(:usage_count)
    update_column(:last_used_at, Time.current)
  end

  # Decrement the usage count for this tag
  # @return [Boolean] true if successful
  def decrement_usage!
    return false if usage_count <= 0

    decrement!(:usage_count)
  end

  # Update the last_used_at timestamp
  # @return [Boolean] true if successful
  def update_last_used!
    touch(:last_used_at)
  end

  private

  # Generate a URL-friendly slug from the tag name
  # Ensures uniqueness by appending a counter if needed
  # @return [void]
  def generate_slug
    return if slug.present? && !name_changed?

    base_slug = name.parameterize
    self.slug = base_slug

    # Handle uniqueness
    counter = 1
    while Tag.where(slug: slug).where.not(id: id).exists?
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
