require "test_helper"

class Scuola::AnagrafeMiurTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships

  ANNO = "202627"

  setup do
    @account = accounts(:fizzy)
    # TipoScuola valida belongs_to :import_scuola (lookup legacy): bypass in test.
    TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
      TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }

    @plesso = Miur::Scuola.create!(codice_scuola: "XXEE00099B", anno_scolastico: ANNO,
      provincia: "XX", comune: "TESTVILLE", denominazione: "PRIMARIA NUOVA",
      tipo_scuola: "SCUOLA PRIMARIA", codice_istituto_riferimento: "XXIC00100X",
      pec: "Non disponibile")
    Miur::Scuola.create!(codice_scuola: "XXIC00100X", anno_scolastico: ANNO,
      provincia: "XX", comune: "TESTVILLE", denominazione: "IC TESTVILLE",
      tipo_scuola: "ISTITUTO COMPRENSIVO")
  end

  test "inserisce plesso e direzione mancante, collegati" do
    Scuola::AnagrafeMiur.new(account: @account, miur_scuole: [@plesso], anno: ANNO).call

    scuola = @account.scuole.find_by(codice_ministeriale: "XXEE00099B")
    direzione = @account.scuole.find_by(codice_ministeriale: "XXIC00100X")
    assert scuola
    assert direzione
    assert_equal direzione.id, scuola.direzione_id
    assert_equal "E", scuola.grado
    assert_nil scuola.pec, "pec 'non disponibile' viene azzerata"
  end

  test "idempotente e non sovrascrive le righe esistenti" do
    Scuola::AnagrafeMiur.new(account: @account, miur_scuole: [@plesso], anno: ANNO).call
    @account.scuole.find_by(codice_ministeriale: "XXEE00099B").update!(denominazione: "RINOMINATA A MANO")

    assert_no_difference -> { @account.scuole.count } do
      Scuola::AnagrafeMiur.new(account: @account, miur_scuole: [@plesso], anno: ANNO).call
    end
    assert_equal "RINOMINATA A MANO",
                 @account.scuole.find_by(codice_ministeriale: "XXEE00099B").denominazione
  end
end
