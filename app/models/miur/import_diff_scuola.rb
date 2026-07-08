# Rollup per scuola toccata da un import MIUR (vedi Miur::ImportDiff).
# categoria: esistente (rettifiche, ha dettaglio righe) | nuova | sparita.
# == Schema Information
#
# Table name: miur_import_diff_scuole
#
#  id              :bigint           not null, primary key
#  categoria       :string           not null
#  codicescuola    :string           not null
#  provincia       :string
#  righe_aggiunte  :integer          default(0), not null
#  righe_rimosse   :integer          default(0), not null
#  tipogradoscuola :string
#  created_at      :datetime         not null
#  import_run_id   :bigint           not null
#
# Indexes
#
#  index_miur_import_diff_scuole_on_import_run_id_and_categoria  (import_run_id,categoria)
#  index_miur_import_diff_scuole_on_import_run_id_and_provincia  (import_run_id,provincia)
#
class Miur::ImportDiffScuola < ApplicationRecord
  self.table_name = "miur_import_diff_scuole"

  belongs_to :import_run, class_name: "Miur::ImportRun"

  scope :esistenti, -> { where(categoria: "esistente") }
  scope :nuove,     -> { where(categoria: "nuova") }
  scope :sparite,   -> { where(categoria: "sparita") }
  scope :per_provincia, ->(provincia) { provincia.present? ? where(provincia: provincia) : all }
end
