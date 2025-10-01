class MessagesController < ApplicationController
  before_action :set_chat

  def create
    return unless content.present?

    # Create user message first
    @user_message = @chat.messages.create!(
      role: 'user',
      content: content
    )

    # Create AI message placeholder for streaming
    @ai_message = @chat.messages.create!(
      role: 'assistant',
      content: ''
    )

    # Enqueue background job to get AI response
    ChatResponseJob.perform_async(@chat.id, content, @ai_message.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @chat }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  def content
    params[:message][:content]
  end

  # def create
  #   return unless content.present?

  #   # Create user message first
  #   @user_message = @chat.messages.create!(
  #     role: 'user',
  #     content: content
  #   )

  #   # Create AI message placeholder for streaming
  #   @ai_message = @chat.messages.create!(
  #     role: 'assistant',
  #     content: ''
  #   )

  #   Rails.logger.info "Enqueuing ChatResponseJob for chat_id: #{@chat.id}, ai_message_id: #{@ai_message.id}"

  #   begin
  #     ChatResponseJob.perform_later(@chat.id, content, @ai_message.id)
  #     Rails.logger.info "ChatResponseJob enqueued successfully"
  #   rescue => e
  #     Rails.logger.error "Failed to enqueue ChatResponseJob: #{e.message}"
  #     Rails.logger.error e.backtrace.join("\n")
  #   end

  #   respond_to do |format|
  #     format.turbo_stream
  #     format.html { redirect_to @chat }
  #   end
  # end

  # private

  # def set_chat
  #   @chat = Chat.find(params[:chat_id])
  # end

  # def content
  #   params[:message][:content]
  # end
end