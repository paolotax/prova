class AddGestioneManualeToScuole < ActiveRecord::Migration[8.1]
  def change
    add_column :scuole, :gestione_manuale, :boolean, default: false, null: false
  end
end
