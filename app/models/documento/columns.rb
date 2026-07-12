# Registro colonne della vista tabella dei documenti.
# Ogni colonna renderizza documenti/table/cells/_<key>; le calcolate si
# aggiungono qui con sort:/scope: alla bisogna.
class Documento::Columns < DataTable::Columns
  self.prefix = "documenti"

  column :stato,     label: "Stato",           width: "7.5rem"
  column :documento, label: "Documento",       width: "11rem", sort: "documenti.data_documento"
  column :collegati, label: "Collegati",       width: "6.5rem", hide_mobile: true
  column :cliente,   label: "Cliente / Scuola", width: "minmax(8rem, 1fr)"
  column :copie,     label: "Copie",           width: "4rem", align: :end, hide_mobile: true,
         sort: "documenti.totale_copie"
  column :importo,   label: "Importo",         width: "7rem", align: :end, hide_mobile: true,
         sort: "documenti.totale_cents"
  column :consegna,  label: "Consegna",        width: "6.5rem", hide_mobile: true
  column :pagamento, label: "Pagamento",       width: "11rem", hide_mobile: true
end
