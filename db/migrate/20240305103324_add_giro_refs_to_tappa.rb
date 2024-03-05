class AddGiroRefsToTappa < ActiveRecord::Migration[7.1]
  def change
    add_reference :tappe, :giro, foreign_key: true
    remove_reference :tappe, :user
  end
end
