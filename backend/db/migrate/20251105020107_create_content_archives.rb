# frozen_string_literal: true

class CreateContentArchives < ActiveRecord::Migration[8.1]
  def change
    create_table :content_archives, id: false do |t|
      t.uuid :id, primary_key: true, default: -> { "uuidv7()" }, null: false

      # Foreign key to links (one-to-one with cascade delete)
      t.references :link,
        type: :uuid,
        null: false,
        foreign_key: {on_delete: :cascade},
        index: {unique: true}

      # Error tracking
      t.text :error_message

      # Extracted content
      t.text :content_html
      t.text :content_text

      # Extracted metadata
      t.string :title, limit: 500
      t.text :description
      t.string :image_url, limit: 2048
      t.jsonb :metadata, default: {}

      # Fetch tracking
      t.datetime :fetched_at

      t.timestamps
    end

    # Additional indexes
    add_index :content_archives, :metadata, using: :gin
    add_index :content_archives, :content_text, using: :gin, opclass: :gin_trgm_ops

    # Drop unused content-related columns from links table
    # These columns were never populated and are being replaced by ContentArchive
    change_table :links do |t|
      t.remove :content_text
      t.remove :raw_html
      t.remove :fetch_error
      t.remove :fetched_at
      t.remove :image_url
      t.remove :title
      t.remove :fetch_state
      # Keep metadata column on links for future non-archive metadata
    end

    # Drop the fetch_state enum type
    drop_enum :link_fetch_state
  end
end
