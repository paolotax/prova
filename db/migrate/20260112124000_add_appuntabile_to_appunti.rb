class AddAppuntabileToAppunti < ActiveRecord::Migration[8.0]
  def change
    add_column :appunti, :appuntabile_type, :string
    add_column :appunti, :appuntabile_id, :uuid
    add_column :appunti, :totale_cents, :integer, default: 0
    add_column :appunti, :totale_copie, :integer, default: 0

    add_index :appunti, [:appuntabile_type, :appuntabile_id]
  end
end
