class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_enum :link_fetch_state, ["pending", "success", "failed"]

    create_table :links, id: false do |t|
      t.uuid :id, primary_key: true, default: -> { "uuidv7()" }, null: false

      # URLs
      t.string :url, null: false, limit: 2048
      t.string :submitted_url, null: false, limit: 2048

      # Content metadata
      t.string :title, limit: 500
      t.text :description
      t.string :image_url, limit: 2048

      # Archived content
      t.text :content_text
      t.text :raw_html

      # Fetch status
      t.enum :fetch_state, enum_type: :link_fetch_state, default: "pending", null: false
      t.text :fetch_error
      t.datetime :fetched_at

      # Flexible metadata storage
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Indexes
    add_index :links, :url, unique: true
    add_index :links, :fetch_state
    add_index :links, :created_at
    add_index :links, :metadata, using: :gin
  end
end
