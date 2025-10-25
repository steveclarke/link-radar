class CreateLinkTags < ActiveRecord::Migration[8.1]
  def change
    create_table :link_tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :link, type: :uuid, null: false, foreign_key: true
      t.references :tag, type: :uuid, null: false, foreign_key: true

      t.datetime :created_at, null: false
    end
    
    add_index :link_tags, [:link_id, :tag_id], unique: true
  end
end
