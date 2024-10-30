class AddAdozioniCountToLibri < ActiveRecord::Migration[7.1]
  def change
    add_column :libri, :adozioni_count, :integer, null: false, default: 0
  end
end
