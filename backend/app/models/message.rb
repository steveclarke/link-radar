# == Schema Information
#
# Table name: messages
#
#  id                    :uuid             not null, primary key
#  cache_creation_tokens :integer
#  cached_tokens         :integer
#  content               :text
#  content_raw           :json
#  input_tokens          :integer
#  output_tokens         :integer
#  role                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  chat_id               :uuid             not null
#  model_id              :uuid
#  tool_call_id          :uuid
#
# Indexes
#
#  index_messages_on_chat_id       (chat_id)
#  index_messages_on_model_id      (model_id)
#  index_messages_on_role          (role)
#  index_messages_on_tool_call_id  (tool_call_id)
#
# Foreign Keys
#
#  fk_rails_...  (chat_id => chats.id)
#  fk_rails_...  (model_id => models.id)
#  fk_rails_...  (tool_call_id => tool_calls.id)
#
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments
end
