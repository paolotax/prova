class AddNavigatorToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :navigator, :string
  end
end
