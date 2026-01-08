class AddAccountToAppunti < ActiveRecord::Migration[8.0]
  def change
    add_reference :appunti, :account, type: :uuid, null: true, index: true
  end
end
