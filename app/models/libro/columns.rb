# Registro colonne della vista tabella dei libri.
class Libro::Columns < DataTable::Columns
  self.prefix = "libri"

  column :copertina,  label: "Copertina",  width: "3rem", hide_mobile: true
  
  column :titolo,     label: "Titolo",     width: "minmax(12rem, 1fr)", sort: "libri.titolo"
  
  column :editore,    label: "Editore",    width: "minmax(7rem, 0.5fr)", hide_mobile: true, sort: "libri.editore_id"
  column :categoria,  label: "Categoria",  width: "minmax(7rem, 0.5fr)", hide_mobile: true, sort: "libri.categoria_id"
  column :isbn,    label: "ISBN",    width: "minmax(7rem, 0.5fr)", hide_mobile: true, sort: "libri.isbn"
  

  column :classe,     label: "Classe",     width: "3.5rem", align: :end, hide_mobile: true, sort: "libri.classe"
  column :disciplina, label: "Disciplina", width: "minmax(7rem, 0.5fr)", hide_mobile: true, sort: "libri.disciplina"
  column :prezzo,     label: "Prezzo",     width: "5.5rem", align: :end, sort: "libri.prezzo_in_cents"
  column :adozioni,   label: "Adozioni",   width: "4.5rem", align: :end, hide_mobile: true, sort: "libri.adozioni_count"
  column :fascicoli,  label: "Fascicoli",  width: "4.5rem", align: :end, hide_mobile: true, default: false,
         sort: "libri.fascicoli_count"
  column :confezioni, label: "Confezioni", width: "4.5rem", align: :end, hide_mobile: true, default: false,
         sort: "libri.confezioni_count"
end
