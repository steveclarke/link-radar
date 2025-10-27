class AddLimitsToTagsColumns < ActiveRecord::Migration[8.1]
  def change
    change_column :tags, :name, :string, limit: 100, null: false
    change_column :tags, :slug, :string, limit: 100, null: false
  end
end
