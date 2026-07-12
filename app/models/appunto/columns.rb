# Registro colonne della vista tabella degli appunti.
class Appunto::Columns < DataTable::Columns
  self.prefix = "appunti"

  column :stato,    label: "Stato",    width: "7.5rem"
  column :appunto,  label: "Appunto",  width: "minmax(10rem, 1.2fr)", sort: "appunti.nome"
  column :soggetto, label: "Soggetto", width: "minmax(8rem, 1fr)"
  column :data,     label: "Data",     width: "6.5rem", hide_mobile: true, sort: "appunti.created_at"
end
