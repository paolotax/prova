# == Schema Information
#
# Table name: prezzi_ministeriali
#
#  id              :uuid             not null, primary key
#  anno_scolastico :string           not null
#  classe          :string           not null
#  disciplina      :string           not null
#  prezzo_cents    :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  idx_prezzi_min_anno_classe_disc  (anno_scolastico,classe,disciplina) UNIQUE
#
require "test_helper"

class PrezzoMinisterialeTest < ActiveSupport::TestCase
  setup do
    Miur::Adozione.delete_all
    PrezzoMinisteriale.delete_all
  end

  test "popola! estrae il prezzo dominante per classe+disciplina" do
    # 150 righe a 4,08 (dominante) + 5 righe a 5,00 per inglese cl.1 (totale 155 > 100, dominanza > 0.9)
    150.times { |i| adoz(sezioneanno: "S#{i}", prezzo: "4,08") }
    5.times   { |i| adoz(sezioneanno: "D#{i}", prezzo: "5,00") }

    n = PrezzoMinisteriale.popola!(anno: ANNO_MIUR)

    assert_equal 1, n
    pm = PrezzoMinisteriale.find_by(anno_scolastico: ANNO_MIUR, classe: "1", disciplina: "LINGUA INGLESE")
    assert_equal 408, pm.prezzo_cents
  end

  test "popola! ignora discipline senza prezzo dominante" do
    # 60/40 split: nessun prezzo supera il 90% di dominanza -> niente PM
    60.times { |i| adoz(sezioneanno: "A#{i}", prezzo: "4,00") }
    40.times { |i| adoz(sezioneanno: "B#{i}", prezzo: "5,00") }

    n = PrezzoMinisteriale.popola!(anno: ANNO_MIUR)

    assert_equal 0, n
  end

  test "popola! filtra per anno: ignora le adozioni di altri anni" do
    # 202627 (target): dominante 4,08. 202526 (altro anno): dominante 9,99.
    150.times { |i| adoz(anno: "202627", sezioneanno: "N#{i}", prezzo: "4,08") }
    150.times { |i| adoz(anno: "202526", sezioneanno: "O#{i}", prezzo: "9,99") }

    n = PrezzoMinisteriale.popola!(anno: "202627")

    assert_equal 1, n
    assert_equal 1, PrezzoMinisteriale.where(anno_scolastico: "202627").count
    assert_equal 0, PrezzoMinisteriale.where(anno_scolastico: "202526").count
    pm = PrezzoMinisteriale.find_by(anno_scolastico: "202627", classe: "1", disciplina: "LINGUA INGLESE")
    assert_equal 408, pm.prezzo_cents # prezzo del 202627, non 999 del 202526
  end

  private

  # Anno di campagna MIUR corrente su cui i test seminano le adozioni.
  ANNO_MIUR = "202627"

  def adoz(sezioneanno:, prezzo:, anno: ANNO_MIUR, disciplina: "LINGUA INGLESE", annocorso: "1")
    Miur::Adozione.create!(
      anno_scolastico: anno,
      codicescuola: "S#{sezioneanno}", annocorso: annocorso, sezioneanno: sezioneanno,
      combinazione: "X", codiceisbn: "I-#{sezioneanno}", disciplina: disciplina,
      titolo: "T", editore: "E", prezzo: prezzo, daacquist: "Sì", tipogradoscuola: "EE"
    )
  end
end
