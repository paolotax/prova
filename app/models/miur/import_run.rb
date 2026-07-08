# == Schema Information
#
# Table name: miur_import_runs
#
#  id                 :bigint           not null, primary key
#  anno_scolastico    :string           not null
#  completed_at       :datetime
#  dataset            :string           default("adozioni"), not null
#  delta_righe        :integer
#  regioni_aggiornate :jsonb            not null
#  regioni_fallite    :jsonb            not null
#  regioni_stale      :jsonb            not null
#  righe_totali       :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_miur_import_runs_on_dataset_and_completed_at  (dataset,completed_at)
#
class Miur::ImportRun < ApplicationRecord
  scope :adozioni, -> { where(dataset: "adozioni") }
  scope :scuole,   -> { where(dataset: "scuole") }

  has_many :diff_scuole, class_name: "Miur::ImportDiffScuola",
           foreign_key: :import_run_id, dependent: :delete_all
  has_many :diff_righe, class_name: "Miur::ImportDiffRiga",
           foreign_key: :import_run_id, dependent: :delete_all

  def diff? = diff_scuole.exists?
end
