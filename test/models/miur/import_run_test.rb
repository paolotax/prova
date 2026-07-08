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
require "test_helper"

class Miur::ImportRunTest < ActiveSupport::TestCase
  test "diff_scuole e diff_righe sono agganciate al run e si distruggono con lui" do
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627")
    run.diff_scuole.create!(codicescuola: "MOEE000001", categoria: "esistente",
                            provincia: "MODENA", righe_aggiunte: 2, righe_rimosse: 1)
    run.diff_righe.create!(codicescuola: "MOEE000001", segno: "+", codiceisbn: "9780000000001")

    assert_equal 1, run.diff_scuole.count
    assert_equal 1, run.diff_righe.count

    run.destroy
    assert_equal 0, Miur::ImportDiffScuola.count
    assert_equal 0, Miur::ImportDiffRiga.count
  end

  test "diff? è vero solo se ci sono scuole toccate" do
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627")
    assert_not run.diff?
    run.diff_scuole.create!(codicescuola: "MOEE000001", categoria: "nuova")
    assert run.diff?
  end
end
