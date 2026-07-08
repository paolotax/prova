# Dettaglio riga del diff import MIUR, solo per scuole "esistente".
# segno '+' = adozione aggiunta dal MIUR, '-' = rimossa.
# == Schema Information
#
# Table name: miur_import_diff_righe
#
#  id            :bigint           not null, primary key
#  annocorso     :string
#  codiceisbn    :string
#  codicescuola  :string           not null
#  combinazione  :string
#  disciplina    :string
#  segno         :string(1)        not null
#  sezioneanno   :string
#  titolo        :string
#  created_at    :datetime         not null
#  import_run_id :bigint           not null
#
# Indexes
#
#  index_miur_import_diff_righe_on_import_run_id_and_codicescuola  (import_run_id,codicescuola)
#
class Miur::ImportDiffRiga < ApplicationRecord
  self.table_name = "miur_import_diff_righe"

  belongs_to :import_run, class_name: "Miur::ImportRun"

  scope :aggiunte, -> { where(segno: "+") }
  scope :rimosse,  -> { where(segno: "-") }

  # Classifica le righe diff di UNA scuola: un ISBN presente sia tra i '+' sia
  # tra i '-' è uno "spostamento" (re-keying MIUR di sezione/classe, il libro
  # non cambia); il resto sono vere aggiunte/rimozioni. Derivata a lettura.
  def self.classifica(righe)
    aggiunti, rimossi = righe.partition { |r| r.segno == "+" }
    comuni = aggiunti.map(&:codiceisbn).to_set & rimossi.map(&:codiceisbn).to_set
    {
      aggiunte: aggiunti.reject { |r| comuni.include?(r.codiceisbn) },
      rimosse:  rimossi.reject { |r| comuni.include?(r.codiceisbn) },
      spostate: righe.select { |r| comuni.include?(r.codiceisbn) }
    }
  end
end
