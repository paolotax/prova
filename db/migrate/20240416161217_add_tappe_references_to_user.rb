class AddTappeReferencesToUser < ActiveRecord::Migration[7.1]
  def change
    add_reference :tappe, :user, null: true, foreign_key: true
  end
end
