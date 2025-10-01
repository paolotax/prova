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
  # broadcasts_to ->(message) { "chat_#{message.chat_id}" } # Disabled to prevent duplicates
  broadcasts_to ->(message) { "chat_#{message.chat_id}" }

  def broadcast_append_chunk(content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      partial: "messages/content",
      locals: { content: content }
  end
  
  # include ActionView::RecordIdentifier

  # acts_as_message

  # after_create_commit -> { broadcast_created }
  # after_update_commit -> { broadcast_updated }

  # def broadcast_created
  #   broadcast_append_later_to(
  #     "#{dom_id(chat)}_messages",
  #     partial: "messages/message",
  #     locals: { message: self, scroll_to: true },
  #     target: "#{dom_id(chat)}_messages"
  #   )
  # end

  # def broadcast_updated
  #   broadcast_replace_to(
  #     "chat_#{chat_id}",
  #     target: dom_id(self),
  #     partial: "messages/message",
  #     locals: { message: self }
  #   )
  # end

  # def broadcast_append_chunk(chunk_content)
  #   # Update the content div with just the raw text for now
  #   broadcast_update_to "chat_#{chat_id}",
  #     target: "message_#{id}_content",
  #     html: self.content

  #   # Trigger scroll to bottom
  #   broadcast_update_to "chat_#{chat_id}",
  #     target: "scroll_trigger",
  #     html: "<script>
  #       setTimeout(() => {
  #         const messagesContainer = document.getElementById('messages');
  #         if (messagesContainer) {
  #           messagesContainer.scrollTop = messagesContainer.scrollHeight;
  #         }
  #       }, 10);
  #     </script>"
  # end

  # def self.for_openai(messages)
  #   messages.map { |message| { role: message.role, content: message.content } }
  # end
end
