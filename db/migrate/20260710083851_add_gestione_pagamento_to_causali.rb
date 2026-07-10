class AddGestionePagamentoToCausali < ActiveRecord::Migration[8.1]
  # Causali per cui il pagamento non ha senso (carichi/campionario/controllo giacenza):
  # il ciclo di queste causali non prevede un incasso da tracciare.
  NON_PAGABILI = [
    "DDT Fornitore", "Carico Fornitore", "Resa a Fornitore", "Campionario",
    "Campionario Resa", "saggi", "saggi 50", "Controllo Giacenza",
    "Conto visione", "Scarico saggi"
  ].freeze

  def up
    add_column :causali, :gestione_pagamento, :boolean, default: true, null: false

    causali = Class.new(ActiveRecord::Base) { self.table_name = "causali" }
    causali.where(causale: NON_PAGABILI).update_all(gestione_pagamento: false)
  end

  def down
    remove_column :causali, :gestione_pagamento
  end
end
