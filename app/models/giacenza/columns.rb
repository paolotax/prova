# Registro colonne della vista tabella delle giacenze (conteggi per anno).
class Giacenza::Columns < DataTable::Columns
  self.prefix = "giacenze"
  self.checkbox = false

  column :titolo,        label: "Titolo",        width: "minmax(15rem, 1fr)", sort: "libri.titolo"
  column :isbn,          label: "ISBN",          width: "7.5rem", hide_mobile: true, sort: "libri.codice_isbn"
  column :adozioni,      label: "Adottati",      width: "5.5rem", align: :end, hide_mobile: true,
         sort: "libri.adozioni_count"
  column :campionario,   label: "Campionario",   width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.campionario, 0)"
  column :saggi_100,     label: "Saggi 100",     width: "5.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.saggi_100, 0)"
  column :saggi_50,      label: "Saggi 50",      width: "5.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.saggi_50, 0)"
  column :scarico_saggi, label: "Scarico saggi", width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.scarico_saggi, 0)"
  column :venduti,       label: "Venduti",       width: "7rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.venduti, 0)"
  column :da_consegnare, label: "Da consegnare", width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.da_consegnare, 0)"
end
