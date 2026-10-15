# == Schema Information
#
# Table name: chats
#
#  id                :uuid             not null, primary key
#  cancelled         :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ruby_llm_model_id :uuid
#
# Indexes
#
#  index_chats_on_ruby_llm_model_id  (ruby_llm_model_id)
#
# Foreign Keys
#
#  fk_rails_...  (ruby_llm_model_id => ruby_llm_models.id)
#
class Chat < ApplicationRecord
  acts_as_chat
end
