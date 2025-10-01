class AllowNullContentInMessages < ActiveRecord::Migration[7.1]
  def change
    change_column_null :messages, :content, true
  end
end

