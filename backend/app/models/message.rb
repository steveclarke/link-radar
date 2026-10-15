# == Schema Information
#
# Table name: messages
#
#  id                    :uuid             not null, primary key
#  cache_creation_tokens :integer
#  cache_ttl             :string
#  cache_until_here      :boolean          default(FALSE), not null
#  cached_tokens         :integer
#  citations             :jsonb
#  content               :text
#  content_raw           :json
#  finish_reason         :string
#  input_tokens          :integer
#  output_tokens         :integer
#  raw_content           :jsonb
#  raw_reasoning         :jsonb
#  role                  :string           not null
#  server_tool_calls     :jsonb
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
#  fk_rails_...  (model_id => ruby_llm_models.id)
#  fk_rails_...  (tool_call_id => ruby_llm_tool_calls.id)
#
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments
end
