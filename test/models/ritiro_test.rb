require "test_helper"

class RitiroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @ritiro = Ritiro.new(@scuola)
  end

  test "bolle ritorna le bolle con almeno una riga aperta o rientrata" do
    assert_includes @ritiro.bolle, bolla_visione_righe(:aperta).bolla_visione
  end

  test "bolle non include bolle con tutte le righe processate (saggio/venduto/mancante)" do
    bv = bolla_visione_righe(:chiusa_in_saggio).bolla_visione
    bv.bolla_visione_righe.update_all(esito: BollaVisioneRiga.esiti[:in_saggio], processato_at: Time.current)
    refute_includes Ritiro.new(@scuola).bolle, bv
  end

  test "righe(bolla) ritorna le righe visibili (aperte + rientrate)" do
    bv = bolla_visione_righe(:aperta).bolla_visione
    righe = @ritiro.righe(bv)
    assert righe.any?
    assert(righe.all? { |r| r.processato_at.nil? || r.rientrato? })
  end

  test "gruppo_per(libro_id, collana_id) ritorna il gruppo da CollanaLibro" do
    riga = bolla_visione_righe(:aperta)
    bolla = riga.bolla_visione
    CollanaLibro.find_or_create_by!(account: accounts(:fizzy), collana: bolla.collana, libro: riga.libro) do |cl|
      cl.gruppo = "Gruppo A"
    end
    assert_equal "Gruppo A", Ritiro.new(@scuola).gruppo_per(riga.libro_id, bolla.collana_id)
  end

  test "gruppo_per ritorna nil se non c'è CollanaLibro" do
    riga = bolla_visione_righe(:aperta)
    bolla = riga.bolla_visione
    CollanaLibro.where(collana: bolla.collana, libro: riga.libro).destroy_all
    assert_nil Ritiro.new(@scuola).gruppo_per(riga.libro_id, bolla.collana_id)
  end

  test "empty? true quando non ci sono bolle" do
    @scuola.bolle_visione.destroy_all
    assert Ritiro.new(@scuola).empty?
  end
end
