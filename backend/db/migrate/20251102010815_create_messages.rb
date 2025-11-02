class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :role, null: false
      t.text :content
      t.integer :input_tokens
      t.integer :output_tokens
      t.timestamps
    end

    add_index :messages, :role
  end
end
