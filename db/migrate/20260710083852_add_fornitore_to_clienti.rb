class AddFornitoreToClienti < ActiveRecord::Migration[8.1]
  # Backfill: fornitore = true per i clienti che compaiono come clientable di
  # almeno un documento la cui causale ha contesto Fornitori o Campionario
  # (vedi Causale#contesto in app/models/causale.rb).
  def up
    add_column :clienti, :fornitore, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE clienti SET fornitore = true
      WHERE id IN (
        SELECT DISTINCT documenti.clientable_id
        FROM documenti
        JOIN causali ON causali.id = documenti.causale_id
        WHERE documenti.clientable_type = 'Cliente'
          AND (causali.magazzino = 'campionario' OR causali.tipo_movimento = 2)
      )
    SQL
  end

  def down
    remove_column :clienti, :fornitore
  end
end
