require "test_helper"

class AdozioneTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole, :classi

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  # Sorgente ImportAdozione che combacia con la classe `prima_a`
  # (origine MIIC123456 / 1 / A), anno_scolastico 202526.
  # insert_all per saltare l'autosave del belongs_to :editore (come ImportAdozione.import in produzione).
  def crea_import_adozione(isbn:)
    ImportAdozione.insert_all([{
      CODICESCUOLA: "MIIC123456",
      ANNOCORSO: "1",
      SEZIONEANNO: "A",
      TIPOGRADOSCUOLA: "EE",
      COMBINAZIONE: "MQ",
      CODICEISBN: isbn,
      TITOLO: "Libro Test #{isbn}",
      EDITORE: "Editore Test",
      AUTORI: "Rossi M.",
      DISCIPLINA: "ITALIANO",
      PREZZO: "10,00",
      NUOVAADOZ: "No",
      DAACQUIST: "Si",
      CONSIGLIATO: "No",
      created_at: Time.current,
      updated_at: Time.current
    }])
    ImportAdozione.find_by(CODICEISBN: isbn)
  end

  test "create_from_import stampa anno_scolastico e codicescuola dalla classe" do
    classe = classi(:prima_a) # anno_scolastico 202526, origine MIIC123456
    imp = crea_import_adozione(isbn: "9788899990001")

    adozione = Adozione.create_from_import(imp, classe: classe, account: classe.account)

    assert_equal classe.anno_scolastico, adozione.anno_scolastico
    assert_equal "202526", adozione.anno_scolastico
    assert_equal classe.codice_ministeriale_origine, adozione.codicescuola
    assert_equal "MIIC123456", adozione.codicescuola
  end

  test "import_for_classe è idempotente (doppio run non duplica le adozioni)" do
    classe = classi(:prima_a)
    crea_import_adozione(isbn: "9788899990001")
    crea_import_adozione(isbn: "9788899990002")

    primo = Adozione.import_for_classe(classe)
    assert_equal 2, primo

    assert_no_difference -> { Adozione.where(classe: classe).count } do
      Adozione.import_for_classe(classe)
    end
  end
end
