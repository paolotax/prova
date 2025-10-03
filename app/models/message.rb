# == Schema Information
#
# Table name: messages
#
#  id              :bigint           not null, primary key
#  content         :string           not null
#  response_number :integer          default(0), not null
#  role            :integer          default("system"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  chat_id         :bigint
#
# Indexes
#
#  index_messages_on_chat_id  (chat_id)
#
# Foreign Keys
#
#  fk_rails_...  (chat_id => chats.id)
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
