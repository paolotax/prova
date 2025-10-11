# == Schema Information
#
# Table name: messages
#
#  id              :bigint           not null, primary key
#  content         :text
#  input_tokens    :integer
#  output_tokens   :integer
#  response_number :integer          default(0), not null
#  role            :string           default("0"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  chat_id         :bigint
#  model_id        :bigint
#  tool_call_id    :bigint
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
  broadcasts_to ->(message) { "chat_#{message.chat_id}" } # Disabled to prevent duplicates

  def broadcast_append_chunk(content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      partial: "messages/content",
      locals: { content: content }
  end
  
  def self.for_openai(messages)
    messages.map { |message| { role: message.role, content: message.content } }
  end
end
