require "test_helper"

class ControlloAnomaliaTest < ActiveSupport::TestCase
  test "TIPI elenca i sei tipi di controllo" do
    assert_equal %w[prezzo_isbn prezzo_disciplina disciplina_mancante doppione tetto_superato scuola_mancante].sort,
                 ControlloAnomalia::TIPI.sort
  end

  test "valida tipo incluso in TIPI" do
    a = ControlloAnomalia.new(codicescuola: "ABC", tipo: "non_esiste")
    assert_not a.valid?
    assert_includes a.errors[:tipo], "non incluso nell'elenco"
  end

  test "scope per_tipo filtra" do
    ControlloAnomalia.create!(codicescuola: "AA", tipo: "doppione")
    ControlloAnomalia.create!(codicescuola: "BB", tipo: "prezzo_isbn")
    assert_equal ["AA"], ControlloAnomalia.per_tipo("doppione").pluck(:codicescuola)
  end

  test "classifica raggruppa per scuola con conteggio decrescente" do
    3.times { ControlloAnomalia.create!(codicescuola: "TANTE", tipo: "doppione") }
    ControlloAnomalia.create!(codicescuola: "POCHE", tipo: "doppione")
    righe = ControlloAnomalia.classifica.to_a
    assert_equal "TANTE", righe.first.codicescuola
    assert_equal 3, righe.first.n_anomalie.to_i
  end
end
