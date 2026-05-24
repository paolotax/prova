class AddStatoToStats < ActiveRecord::Migration[8.1]
  def change
    add_column :stats, :stato, :string, default: "lab", null: false
    add_column :stats, :ultima_verifica, :datetime
    add_column :stats, :ultimo_errore, :text
    add_index :stats, :stato
  end
end
