require "test_helper"

class Libro::SituazioneTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
           :libri, :categorie, :editori, :righe, :documento_righe

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @situazione = Libro::Situazione.new(accounts(:fizzy))
  end

  teardown do
    Current.reset
  end

  test "una colonna per ogni causale, quantità aggregate" do
    riga = @situazione.righe.find { |r| r["id"] == libri(:libro_fizzy).id }

    assert riga, "libro_fizzy deve comparire"
    # fixture per libro_fizzy (padre-nil): Vendita 10, TD01 20+15, TD04 3
    assert_equal 10, riga["Vendita"]
    assert_equal 35, riga["TD01"]
    assert_equal 3, riga["TD04"]
    assert_equal libri(:libro_fizzy).codice_isbn, riga["codice_isbn"]
  end

  test "esclude i documenti figli" do
    riga = @situazione.righe.find { |r| r["id"] == libri(:libro_fizzy).id }
    # ordine_figlio (8 copie, causale Ordine) ha documento_padre: escluso
    assert_equal 0, riga["Ordine"]
  end

  test "esclude gli altri account" do
    ids = @situazione.righe.map { |r| r["id"] }
    assert_not_includes ids, libri(:libro_acme).id
  end

  test "le intestazioni contengono libro, causali e anagrafica" do
    intestazioni = @situazione.righe.first.keys
    assert_includes intestazioni, "titolo"
    assert_includes intestazioni, "TD01"
    assert_includes intestazioni, "editore"
  end
end
