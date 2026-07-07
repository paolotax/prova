require "test_helper"

class AggiungiScuoleNuoveJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :scuole

  ANNO = "202627"

  setup do
    @account = accounts(:fizzy)
    # TipoScuola valida belongs_to :import_scuola (lookup legacy): bypass in test.
    TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
      TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }
    @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA", stato: "attiva")

    Miur::Scuola.create!(codice_scuola: "XXEE00099B", anno_scolastico: ANNO, provincia: "XX",
      comune: "TESTVILLE", denominazione: "PRIMARIA NUOVA", tipo_scuola: "SCUOLA PRIMARIA",
      codice_istituto_riferimento: "XXIC00100X")
    Miur::Scuola.create!(codice_scuola: "XXIC00100X", anno_scolastico: ANNO, provincia: "XX",
      comune: "TESTVILLE", denominazione: "IC TESTVILLE", tipo_scuola: "ISTITUTO COMPRENSIVO")
    Miur::Adozione.create!(codicescuola: "XXEE00099B", anno_scolastico: ANNO, tipogradoscuola: "EE",
      annocorso: "1", sezioneanno: "A", combinazione: "TN",
      codiceisbn: "9880000000029", daacquist: "Si", prezzo: "12,50")
  end

  test "crea scuola, direzione, classi e adozioni dal ministeriale" do
    AggiungiScuoleNuoveJob.perform_now(@account, provincia: "XX")

    scuola = @account.scuole.find_by(codice_ministeriale: "XXEE00099B")
    assert scuola, "la nuova scuola entra in anagrafe"
    assert_equal "E", scuola.grado
    assert_equal "XX", scuola.provincia

    direzione = @account.scuole.find_by(codice_ministeriale: "XXIC00100X")
    assert direzione, "anche la direzione mancante viene creata"
    assert_equal direzione.id, scuola.direzione_id

    classe = scuola.classi.attive.find_by(anno_scolastico: ANNO, anno_corso: "1", sezione: "A")
    assert classe, "il reconcile crea la classe dal ministeriale"
    assert_equal 1, classe.adozioni.where(codice_isbn: "9880000000029").count
  end

  test "idempotente: un secondo run non crea doppioni" do
    AggiungiScuoleNuoveJob.perform_now(@account, provincia: "XX")

    assert_no_difference [-> { @account.scuole.count }, -> { @account.classi.count },
                          -> { @account.adozioni.count }] do
      AggiungiScuoleNuoveJob.perform_now(@account, provincia: "XX")
    end
  end

  test "codici: aggiunge solo la scuola richiesta (aggiunta singola dalla riga)" do
    # Una seconda nuova in altro comune (nessun candidato → nuova).
    Miur::Scuola.create!(codice_scuola: "XXEE00077A", anno_scolastico: ANNO, provincia: "XX",
      comune: "ALTROPAESE", denominazione: "PRIMARIA DUE", tipo_scuola: "SCUOLA PRIMARIA")
    Miur::Adozione.create!(codicescuola: "XXEE00077A", anno_scolastico: ANNO, tipogradoscuola: "EE",
      annocorso: "1", sezioneanno: "A", combinazione: "TN",
      codiceisbn: "9880000000060", daacquist: "Si")

    AggiungiScuoleNuoveJob.perform_now(@account, provincia: "XX", codici: ["XXEE00099B"])

    assert @account.scuole.find_by(codice_ministeriale: "XXEE00099B"), "aggiunge la scuola richiesta"
    assert_nil @account.scuole.find_by(codice_ministeriale: "XXEE00077A"), "non tocca le altre nuove"
  end

  test "non tocca i codici con candidati predecessore" do
    # Orfana nello stesso comune e natura: XXEE00099B diventa un suggerimento, non una nuova.
    @account.scuole.create!(codice_ministeriale: "XXEE00001Z", provincia: "XX",
      comune: "TESTVILLE", denominazione: "Primaria Vecchia",
      tipo_scuola: "SCUOLA PRIMARIA", grado: "E")

    AggiungiScuoleNuoveJob.perform_now(@account, provincia: "XX")

    assert_nil @account.scuole.find_by(codice_ministeriale: "XXEE00099B"),
               "un codice con candidati va risolto a mano, non aggiunto come nuova scuola"
  end
end
