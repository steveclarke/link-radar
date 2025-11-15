# Represents a captured link in LinkRadar
#
# == Schema Information
#
# Table name: links
#
#  id                :uuid             not null, primary key
#  note              :text
#  search_projection :text
#  url               :string(2048)     not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_links_on_created_at  (created_at)
#  index_links_on_url         (url) UNIQUE
#
class Link < ApplicationRecord
  include Saltbox::SortByColumns::Model
  include Searchable

  # Search configuration
  searchable_with SearchContent::Link, project: true

  # Associations
  has_many :link_tags, dependent: :destroy
  has_many :tags, through: :link_tags
  has_one :content_archive, dependent: :destroy

  # Virtual attribute for tag assignment
  attr_accessor :tag_names

  # Configure sortable columns
  sort_by_columns :created_at, :updated_at, :c_tag_count

  # Find link by URL with normalization
  # Normalizes the input URL the same way we normalize before saving
  #
  # @param url [String] URL to search for (with or without scheme)
  # @return [Link, nil] found link or nil
  def self.find_by_url(url)
    return nil if url.blank?

    normalized_url = normalize_url_string(url)
    find_by(url: normalized_url)
  rescue Addressable::URI::InvalidURIError
    nil # Invalid URL returns nil (not found)
  end

  # Find link by URL with normalization (raises exception if not found)
  # Normalizes the input URL the same way we normalize before saving
  #
  # @param url [String] URL to search for (with or without scheme)
  # @return [Link] found link
  # @raise [ActiveRecord::RecordNotFound] if link is not found
  def self.find_by_url!(url)
    find_by_url(url) || raise(ActiveRecord::RecordNotFound, "Couldn't find Link with URL: #{url}")
  end

  # Normalize a URL string
  # Adds HTTPS scheme if missing and applies Addressable normalization
  #
  # @param url [String] URL to normalize
  # @return [String] normalized URL
  # @raise [Addressable::URI::InvalidURIError] if URL is invalid
  def self.normalize_url_string(url)
    url_with_scheme = url.match?(/\A[a-z][a-z0-9+\-.]*:/i) ? url : "https://#{url}"
    uri = Addressable::URI.parse(url_with_scheme)
    uri.normalize!
    uri.to_s
  end

  # Custom scope for sorting by tag count
  scope :sorted_by_tag_count, ->(direction) {
    # Validate direction to prevent SQL injection
    validated_direction = direction.to_s.upcase
    unless %w[ASC DESC].include?(validated_direction)
      raise ArgumentError, "Invalid sort direction: #{direction}. Must be ASC or DESC"
    end

    left_joins(:link_tags)
      .group("links.id")
      .order(Arel.sql("COUNT(link_tags.id) #{validated_direction}, links.created_at #{validated_direction}"))
  }

  # Fetch state enum backed by Postgres enum type
  # Removed - migrated to ContentArchive state machine
  # enum :fetch_state, {
  #   pending: "pending",
  #   success: "success",
  #   failed: "failed"
  # }, prefix: true

  # Validations
  validates :url, presence: true, length: {maximum: 2048}, uniqueness: true
  validate :url_must_be_valid

  # Callbacks
  before_validation :normalize_url, if: :url_changed?

  after_create :create_content_archive_and_enqueue_job
  # Check @tag_names (instance variable) to distinguish: nil (not provided) vs [] (clear tags)
  after_save :process_tag_names, if: -> { !@tag_names.nil? }

  private

  # Creates ContentArchive and enqueues background archival job
  #
  # This callback is triggered after a Link is created. It:
  # 1. Checks if content archival is enabled (early return if disabled)
  # 2. Creates a ContentArchive record (initial state: pending)
  # 3. Enqueues ArchiveContentJob to process content asynchronously
  #
  # Archival failures never block link creation - if archival is disabled,
  # callback returns silently. Job failures are handled gracefully by the Archiver service.
  #
  # @return [void]
  def create_content_archive_and_enqueue_job
    config = ContentArchiveConfig.new
    return unless config.enabled

    archive = ContentArchive.create!(link: self)
    ArchiveContentJob.perform_later(link_id: id)

    Rails.logger.info "ContentArchive #{archive.id} created and job enqueued for Link #{id}"
  rescue => e
    Rails.logger.error "Failed to create ContentArchive for Link #{id}: #{e.message}"
  end

  # Callback orchestrator for processing tag names after save
  #
  # This method is triggered by the after_save callback when @tag_names is set.
  # It wraps the core tag assignment logic in a transaction and handles cleanup.
  #
  # @note This is a private callback method. For direct tag assignment, use {#assign_tags}.
  # @see #assign_tags for the core tag assignment logic
  # @return [void]
  def process_tag_names
    transaction do
      assign_tags(@tag_names)
    end
  ensure
    # Clear the virtual attribute after processing
    @tag_names = nil
  end

  # Core logic for assigning tags to a link
  #
  # Normalizes tag names, finds or creates Tag records, and replaces the link's
  # current tags with the new set. This method contains the business logic for
  # tag assignment and can be called directly or via the callback orchestrator.
  #
  # @param tag_names [Array<String>] array of tag names (empty array clears all tags)
  # @return [Array<Tag>] the assigned tags
  # @see #process_tag_names for the callback wrapper that invokes this method
  def assign_tags(tag_names)
    # Normalize tag names
    normalized_names = Array(tag_names).map(&:strip).compact_blank.uniq

    # Find or create tags
    new_tags = normalized_names.map do |name|
      Tag.find_or_create_by(name: name)
    end

    # Replace existing tags with new set (including empty array to clear all)
    self.tags = new_tags
  end

  # Normalize URL by ensuring scheme is present and applying standard normalization
  # Defaults to HTTPS (industry standard in 2025) if no scheme provided
  # Uses Addressable for robust parsing and normalization
  # Runs automatically before validation when URL changes
  def normalize_url
    return if url.blank?

    self.url = self.class.normalize_url_string(url)
  rescue Addressable::URI::InvalidURIError
    # Let the validation handle the error message
    # Don't modify invalid URLs
  end

  # Custom validation for URL format
  def url_must_be_valid
    return if url.blank? # presence validation handles this

    Addressable::URI.parse(url)
  rescue Addressable::URI::InvalidURIError => e
    errors.add(:url, "is not a valid URL: #{e.message}")
  end
end
