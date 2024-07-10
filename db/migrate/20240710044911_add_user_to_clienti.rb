class AddUserToClienti < ActiveRecord::Migration[7.1]
  def change
    add_reference :clienti, :user, null: false, foreign_key: true
  end
end
