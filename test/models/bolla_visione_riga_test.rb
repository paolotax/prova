require "test_helper"

class BollaVisioneRigaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :scuole, :collane, :bolle_visione, :bolla_visione_righe

  test "scope aperte ritorna righe senza processato_at" do
    riga = bolla_visione_righe(:aperta)
    assert_includes BollaVisioneRiga.aperte, riga
    assert_not_includes BollaVisioneRiga.chiuse, riga
  end

  test "scope chiuse ritorna righe con processato_at" do
    riga = bolla_visione_righe(:chiusa_in_saggio)
    assert_includes BollaVisioneRiga.chiuse, riga
    assert_not_includes BollaVisioneRiga.aperte, riga
  end

  test "esito enum mappa i 5 valori attesi" do
    assert_equal({ "in_saggio" => 0, "venduto_fattura" => 1, "venduto_corrispettivi" => 2,
                   "mancante" => 3, "rientrato" => 4 }, BollaVisioneRiga.esiti)
  end
end
