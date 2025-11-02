class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.timestamps
    end
  end
end
