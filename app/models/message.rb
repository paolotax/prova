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
  include ActionView::RecordIdentifier

  enum :role, { system: 0, assistant: 10, user: 20 }

  belongs_to :chat

  after_create_commit -> { broadcast_created }
  after_update_commit -> { broadcast_updated }

  def broadcast_created
    broadcast_append_later_to(
      "#{dom_id(chat)}_messages",
      partial: "messages/message",
      locals: { message: self, scroll_to: true },
      target: "#{dom_id(chat)}_messages"
    )
  end

  def broadcast_updated
    broadcast_append_to(
      "#{dom_id(chat)}_messages",
      partial: "messages/message",
      locals: { message: self, scroll_to: true },
      target: "#{dom_id(chat)}_messages"
    )
  end

  def self.for_openai(messages)
    messages.map { |message| { role: message.role, content: message.content } }
  end
end
