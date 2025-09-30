class AddReferencesToTablesForRubyLlm < ActiveRecord::Migration[8.0]
  def change
    # Add model reference to chats
    add_reference :chats, :model, foreign_key: true

    # Add message reference to tool_calls
    add_reference :tool_calls, :message, null: false, foreign_key: true

    # Add model and tool_call references to messages
    add_reference :messages, :model, foreign_key: true
    add_reference :messages, :tool_call, foreign_key: true

    # Add index for role (model_id and tool_call_id indexes are created automatically by add_reference)
    add_index :messages, :role
  end
end