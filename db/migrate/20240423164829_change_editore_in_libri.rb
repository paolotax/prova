class ChangeEditoreInLibri < ActiveRecord::Migration[7.1]
  def change
    change_column :libri, :editore_id, :bigint, null: true
  end
end
