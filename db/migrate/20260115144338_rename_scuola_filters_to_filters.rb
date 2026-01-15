class RenameScuolaFiltersToFilters < ActiveRecord::Migration[8.0]
  def change
    # Rinomina tabella
    rename_table :scuola_filters, :filters

    # Aggiungi colonna type per STI
    add_column :filters, :type, :string

    # Imposta type per record esistenti
    reversible do |dir|
      dir.up do
        execute "UPDATE filters SET type = 'Filters::Scuola' WHERE type IS NULL"
      end
    end

    # Rendi type not null dopo aver impostato i valori
    change_column_null :filters, :type, false

    # Aggiorna indice per includere type
    remove_index :filters, :params_digest
    add_index :filters, [:type, :params_digest], unique: true
  end
end
