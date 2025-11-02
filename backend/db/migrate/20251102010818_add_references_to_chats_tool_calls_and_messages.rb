class AddReferencesToChatsToolCallsAndMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :chats, :model, type: :uuid, foreign_key: true
    add_reference :tool_calls, :message, type: :uuid, null: false, foreign_key: true
    add_reference :messages, :chat, type: :uuid, null: false, foreign_key: true
    add_reference :messages, :model, type: :uuid, foreign_key: true
    add_reference :messages, :tool_call, type: :uuid, foreign_key: true
  end
end
