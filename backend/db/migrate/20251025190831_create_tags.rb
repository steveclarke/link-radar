class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :usage_count, default: 0, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    
    add_index :tags, :name
    add_index :tags, :slug, unique: true
  end
end
