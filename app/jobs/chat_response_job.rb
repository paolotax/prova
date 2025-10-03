class ChatResponseJob

  include Sidekiq::Worker

  def perform(chat_id, content)
    chat = Chat.find(chat_id)
    chat.with_tools(LibriTool, AppuntiTool).ask(content) do |chunk|
      if chunk.content && !chunk.content.blank?
        message = chat.messages.last
        message.broadcast_append_chunk(chunk.content)
      end
    end
  end
end