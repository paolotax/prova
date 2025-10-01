class ChatsController < ApplicationController
  before_action :set_chat, only: [:show]

  def index
    @chats = current_user.chats.order(created_at: :desc)
  end

  def new
    @chat = current_user.chats.build
    @selected_model = params[:model]
  end

  def create
    return unless prompt.present?

    @chat = current_user.chats.create!(model: model)
    
    # Create user message
    user_message = @chat.messages.create!(
      role: 'user',
      content: prompt
    )
    
    # Create AI message placeholder
    ai_message = @chat.messages.create!(
      role: 'assistant',
      content: ''
    )
    
    ChatResponseJob.perform_async(@chat.id, prompt, ai_message.id)

    redirect_to @chat, notice: 'Chat was successfully created.'
  end

  def show
    @message = @chat.messages.build
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end

  def model
    params[:chat][:model].presence
  end

  def prompt
    params[:chat][:prompt]
  end
end