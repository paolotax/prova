class ChatResponseJob

  include Sidekiq::Worker

  def perform(chat_id, content, ai_message_id)
    chat = Chat.find(chat_id)
    ai_message = Message.find(ai_message_id)

    chat.with_tools(LibriTool, AppuntiTool).ask(content) do |chunk|
      if chunk.content && !chunk.content.blank?
        # Append chunk content to the AI message
        ai_message.update_column(:content, ai_message.content.to_s + chunk.content)
        ai_message.broadcast_append_chunk(chunk.content)
      end
    end
  end

  # def perform(chat_id, content, ai_message_id)
  #   Rails.logger.info "ChatResponseJob started for chat_id: #{chat_id}, message_id: #{ai_message_id}"

  #   chat = Chat.find(chat_id)
  #   ai_message = Message.find(ai_message_id)

  #   Rails.logger.info "Found chat: #{chat.id}, ai_message: #{ai_message.id}"

  #   # Check if chat responds to ask method
  #   unless chat.respond_to?(:ask)
  #     Rails.logger.error "Chat does not respond to :ask method"
  #     ai_message.update!(content: "Errore: il metodo ask non è disponibile per questo chat.")
  #     returndef create
  #     return unless content.present?
  
  #     # Create user message first
  #     @user_message = @chat.messages.create!(
  #       role: 'user',
  #       content: content
  #     )
  
  #     # Create AI message placeholder for streaming
  #     @ai_message = @chat.messages.create!(
  #       role: 'assistant',
  #       content: ''
  #     )
  
  #     Rails.logger.info "Enqueuing ChatResponseJob for chat_id: #{@chat.id}, ai_message_id: #{@ai_message.id}"
  
  #     begin
  #       ChatResponseJob.perform_later(@chat.id, content, @ai_message.id)
  #       Rails.logger.info "ChatResponseJob enqueued successfully"
  #     rescue => e
  #       Rails.logger.error "Failed to enqueue ChatResponseJob: #{e.message}"
  #       Rails.logger.error e.backtrace.join("\n")
  #     end
  
  #     respond_to do |format|
  #       format.turbo_stream
  #       format.html { redirect_to @chat }
  #     end
  #   end

  #   begin
  #     # Real API call with streaming
  #     chat.ask(content) do |chunk|
  #       Rails.logger.info "Received chunk: #{chunk.inspect}"
  #       if chunk.content && !chunk.content.blank?
  #         # Append chunk to existing content
  #         ai_message.update_column(:content, ai_message.content + chunk.content)
  #         ai_message.broadcast_append_chunk(chunk.content)
  #       end
  #     end

  #     Rails.logger.info "AI response completed successfully"

  #     # Final update with markdown rendering
  #     ai_message.reload
  #     ai_message.broadcast_updated
  #   rescue => e
  #     Rails.logger.error "Error in ChatResponseJob: #{e.message}"
  #     Rails.logger.error e.backtrace.join("\n")
  #     ai_message.update!(content: "Errore nella generazione della risposta: #{e.message}")
  #   end
  # end
end