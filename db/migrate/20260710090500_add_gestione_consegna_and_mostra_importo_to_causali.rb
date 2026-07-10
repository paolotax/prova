class AddGestioneConsegnaAndMostraImportoToCausali < ActiveRecord::Migration[8.1]
  # Causali per cui la consegna non ha senso (carichi/campionario/controllo giacenza):
  # il ciclo di queste causali non prevede una consegna fisica da tracciare.
  # Scarico saggi e Conto visione restano gestione_consegna: true (consegna fisica reale).
  NON_CONSEGNABILI = [
    "DDT Fornitore", "Carico Fornitore", "TD24", "Resa a Fornitore", "Campionario",
    "Campionario Resa", "saggi", "saggi 50", "Controllo Giacenza"
  ].freeze

  # Scarico saggi ha righe a sconto 100: l'importo è sempre zero, va nascosto.
  NON_MOSTRA_IMPORTO = [ "Scarico saggi" ].freeze

  def up
    add_column :causali, :gestione_consegna, :boolean, default: true, null: false
    add_column :causali, :mostra_importo, :boolean, default: true, null: false

    causali = Class.new(ActiveRecord::Base) { self.table_name = "causali" }
    causali.where(causale: NON_CONSEGNABILI).update_all(gestione_consegna: false)
    causali.where(causale: NON_MOSTRA_IMPORTO).update_all(mostra_importo: false)
  end

  def down
    remove_column :causali, :gestione_consegna
    remove_column :causali, :mostra_importo
  end
end
