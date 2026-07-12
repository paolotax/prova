# Registro colonne della vista tabella dei contatti (persone).
# Il filtro dedupa via subquery, quindi il sort sulle colonne di scuole
# con left_joins è sicuro.
class Persona::Columns < DataTable::Columns
  self.prefix = "persone"

  column :ruolo,    label: "Ruolo",    width: "7rem", hide_mobile: true, sort: "persone.ruolo"
  column :nome,     label: "Contatto", width: "minmax(11rem, 1fr)", sort: "persone.cognome"
  column :scuola,   label: "Scuola",   width: "minmax(11rem, 1fr)", hide_mobile: true,
         sort: "scuole.denominazione", scope: ->(s) { s.left_joins(:scuola) }
  column :comune,   label: "Comune",   width: "minmax(8rem, 0.5fr)",
         sort: "scuole.comune", scope: ->(s) { s.left_joins(:scuola) }
  column :contatti, label: "Contatti", width: "minmax(10rem, 0.8fr)", hide_mobile: true
  column :classi,   label: "Classi",   width: "4.5rem", align: :end, hide_mobile: true, default: false
end
