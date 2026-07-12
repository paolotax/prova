# Registro colonne della vista tabella delle scuole.
# Sort per provincia usa il nome esteso (sigla_provincia spesso vuota).
class Scuola::Columns < DataTable::Columns
  self.prefix = "scuole"

  column :tipo,          label: "Tipo",      width: "6.5rem", hide_mobile: true, sort: "scuole.tipo_scuola"
  column :denominazione, label: "Scuola",    width: "minmax(12rem, 1fr)", sort: "scuole.denominazione"
  column :comune,        label: "Comune",    width: "minmax(8rem, 0.6fr)", sort: "scuole.comune"
  column :provincia,     label: "Provincia", width: "6rem", hide_mobile: true, sort: "scuole.provincia"
  column :contatti,      label: "Contatti",  width: "minmax(10rem, 0.8fr)", hide_mobile: true
  column :adozioni,      label: "Adozioni",  width: "5rem", align: :end, hide_mobile: true,
         sort: "scuole.mie_adozioni_count"
end
