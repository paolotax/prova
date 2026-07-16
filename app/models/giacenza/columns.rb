# Registro colonne della vista tabella delle giacenze.
class Giacenza::Columns < DataTable::Columns
  self.prefix = "giacenze"
  self.checkbox = false

  LIBERO_SQL = "COALESCE(giacenze.disponibile, 0) - COALESCE(giacenze.impegnato, 0)".freeze
  FABBISOGNO_SQL = "GREATEST(libri.adozioni_count - (#{LIBERO_SQL}), 0)".freeze

  column :titolo,      label: "Titolo",        width: "minmax(15rem, 1fr)", sort: "libri.titolo"
  column :isbn,        label: "ISBN",          width: "7.5rem", hide_mobile: true, sort: "libri.codice_isbn"
  column :disponibile, label: "Disponibile",   width: "6rem", align: :end, hide_mobile: true,
         sort: "COALESCE(giacenze.disponibile, 0)"
  column :impegnato,   label: "Da consegnare", width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(giacenze.impegnato, 0)"
  column :libero,      label: "Libero",        width: "5rem", align: :end, hide_mobile: true, sort: LIBERO_SQL
  column :adozioni,    label: "Adozioni",      width: "5.5rem", align: :end, hide_mobile: true,
         sort: "libri.adozioni_count"
  column :fabbisogno,  label: "Fabbisogno",    width: "6rem", align: :end, hide_mobile: true, sort: FABBISOGNO_SQL
  column :campionario, label: "Campionario",   width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(giacenze.campionario, 0)"
  column :vendute,     label: "Vendute",       width: "7rem", align: :end, hide_mobile: true,
         sort: "COALESCE(giacenze.venduto_copie, 0)"
end
