# Registro colonne della vista tabella dei clienti.
# Copie/Da pagare vengono dal saldo denormalizzato (Saldabile).
class Cliente::Columns < DataTable::Columns
  self.prefix = "clienti"

  column :tipo,          label: "Tipo",      width: "8rem", hide_mobile: true, sort: "clienti.tipo_cliente"
  column :denominazione, label: "Cliente",   width: "minmax(12rem, 1fr)", sort: "clienti.denominazione"
  column :comune,        label: "Comune",    width: "minmax(8rem, 0.6fr)", sort: "clienti.comune"
  column :provincia,     label: "Provincia", width: "6rem", hide_mobile: true, sort: "clienti.provincia"
  column :contatti,      label: "Contatti",  width: "minmax(10rem, 0.8fr)", hide_mobile: true
  column :piva,          label: "P.IVA / CF", width: "9rem", hide_mobile: true, default: false
  column :copie,         label: "Copie",     width: "5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(saldi.copie_da_consegnare, 0)",
         scope: ->(s) { s.left_joins(:saldo) }
  column :da_pagare,     label: "Da pagare", width: "7rem", align: :end, hide_mobile: true,
         sort: "COALESCE(saldi.importo_da_pagare_cents, 0)",
         scope: ->(s) { s.left_joins(:saldo) }
end
