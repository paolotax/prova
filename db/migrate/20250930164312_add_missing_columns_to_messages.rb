class AddMissingColumnsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :input_tokens, :integer
    add_column :messages, :output_tokens, :integer

    # Change content from string to text
    change_column :messages, :content, :text

    # Change role from integer to string (varchar)
    change_column :messages, :role, :string, null: false
  end
end
