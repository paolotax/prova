class AddClientableTypeToCausali < ActiveRecord::Migration[7.2]
  def change
    add_column :causali, clientable_type: :string
  end
end
