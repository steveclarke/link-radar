class AddUpdatedAtToLinkTags < ActiveRecord::Migration[8.1]
  def change
    add_column :link_tags, :updated_at, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" }
  end
end
