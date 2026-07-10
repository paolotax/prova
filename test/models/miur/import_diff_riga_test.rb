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
require "test_helper"

class Miur::ImportDiffRigaTest < ActiveSupport::TestCase
  test "classifica separa aggiunte/rimosse vere dagli spostamenti (stesso isbn su entrambi i segni)" do
    righe = [
      riga(segno: "+", codiceisbn: "9781111111111", sezioneanno: "AAFM"), # spostata (isbn anche in -)
      riga(segno: "-", codiceisbn: "9781111111111", sezioneanno: "A"),    # spostata
      riga(segno: "+", codiceisbn: "9782222222222", sezioneanno: "B"),    # vera aggiunta
      riga(segno: "-", codiceisbn: "9783333333333", sezioneanno: "C")     # vera rimozione
    ]

    c = Miur::ImportDiffRiga.classifica(righe)

    assert_equal ["9782222222222"], c[:aggiunte].map(&:codiceisbn)
    assert_equal ["9783333333333"], c[:rimosse].map(&:codiceisbn)
    assert_equal %w[9781111111111 9781111111111], c[:spostate].map(&:codiceisbn).sort
  end

  test "classifica con righe vuote torna gruppi vuoti" do
    c = Miur::ImportDiffRiga.classifica([])
    assert_equal [], c[:aggiunte]
    assert_equal [], c[:rimosse]
    assert_equal [], c[:spostate]
  end

  private

  def riga(attrs)
    Miur::ImportDiffRiga.new({ codicescuola: "MIIC123456", disciplina: "ITALIANO",
                               annocorso: "1", combinazione: "X" }.merge(attrs))
  end
end
