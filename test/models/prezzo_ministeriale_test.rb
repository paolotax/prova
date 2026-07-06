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
    NewAdozione.delete_all
    PrezzoMinisteriale.delete_all
  end

  test "anno_scolastico_corrente da febbraio in poi e' anno/anno+1" do
    assert_equal "2026/2027", PrezzoMinisteriale.anno_scolastico_corrente(Date.new(2026, 6, 17))
    assert_equal "2026/2027", PrezzoMinisteriale.anno_scolastico_corrente(Date.new(2026, 2, 1))
    assert_equal "2025/2026", PrezzoMinisteriale.anno_scolastico_corrente(Date.new(2026, 1, 15))
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

  private

  # Anno di campagna MIUR usato dai writer di test (default di NewAdozione con
  # anagrafe scuole vuota): coincide con la partizione su cui popola! legge.
  ANNO_MIUR = "202627"

  def adoz(sezioneanno:, prezzo:, disciplina: "LINGUA INGLESE", annocorso: "1")
    NewAdozione.create!(
      anno_scolastico: ANNO_MIUR,
      codicescuola: "S#{sezioneanno}", annocorso: annocorso, sezioneanno: sezioneanno,
      combinazione: "X", codiceisbn: "I-#{sezioneanno}", disciplina: disciplina,
      titolo: "T", editore: "E", prezzo: prezzo, daacquist: "Sì", tipogradoscuola: "EE"
    )
  end
end
