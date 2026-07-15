require "test_helper"

# Silenzia i broadcast (renderizzano partial, fuori scope): la logica di
# import resta reale.
class ImportScuolePerZonaJobSilent < ImportScuolePerZonaJob
  private
  def broadcast_zone_panel(_account) = nil
  def broadcast_scuole_refresh(_account) = nil
  def broadcast_pulsante_stato(_account) = nil
end

class ImportScuolePerZonaJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships

  ANNO_CORRENTE = "202627"
  ANNO_PRECEDENTE = "202526"

  setup do
    @account = accounts(:fizzy)
    # TipoScuola valida belongs_to :import_scuola (lookup legacy): bypass in test.
    TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
      TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }
    @zona = @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA",
                                  stato: "pronta")

    Miur::Scuola.create!(codice_scuola: "XXEE00099B", anno_scolastico: ANNO_CORRENTE,
      provincia: "XX", comune: "TESTVILLE", denominazione: "PRIMARIA NUOVA",
      tipo_scuola: "SCUOLA PRIMARIA", codice_istituto_riferimento: "XXIC00100X")
    Miur::Scuola.create!(codice_scuola: "XXIC00100X", anno_scolastico: ANNO_CORRENTE,
      provincia: "XX", comune: "TESTVILLE", denominazione: "IC TESTVILLE",
      tipo_scuola: "ISTITUTO COMPRENSIVO")

    Miur::Adozione.create!(codicescuola: "XXEE00099B", anno_scolastico: ANNO_CORRENTE,
      tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
      codiceisbn: "9880000000029", daacquist: "Si", prezzo: "12,50")
    Miur::Adozione.create!(codicescuola: "XXEE00099B", anno_scolastico: ANNO_PRECEDENTE,
      tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
      codiceisbn: "9880000000012", daacquist: "Si", prezzo: "11,00")
  end

  test "importa anagrafe e riconcilia corrente (attivo) + precedente (archiviato)" do
    ImportScuolePerZonaJobSilent.perform_now(@zona)

    scuola = @account.scuole.find_by(codice_ministeriale: "XXEE00099B")
    assert scuola, "il plesso entra in anagrafe"
    assert @account.scuole.find_by(codice_ministeriale: "XXIC00100X"), "anche la direzione"

    corrente = scuola.classi.find_by(anno_scolastico: ANNO_CORRENTE, anno_corso: "1", sezione: "A")
    assert corrente, "classe dell'anno corrente creata"
    assert_equal "attiva", corrente.stato
    assert_equal 1, corrente.adozioni.where(codice_isbn: "9880000000029").count

    storico = scuola.classi.find_by(anno_scolastico: ANNO_PRECEDENTE, anno_corso: "1", sezione: "A")
    assert storico, "classe dell'anno precedente creata"
    assert_equal "archiviata", storico.stato, "lo storico 25/26 nasce archiviato"
    assert_equal 1, storico.adozioni.where(codice_isbn: "9880000000012").count

    assert_equal "attiva", @zona.reload.stato
    assert_equal 1, @zona.scuole_count, "conta solo i plessi del grado, non la direzione"
  end

  test "idempotente: un secondo run non crea doppioni" do
    ImportScuolePerZonaJobSilent.perform_now(@zona)

    assert_no_difference [-> { @account.scuole.count }, -> { @account.classi.count },
                          -> { @account.adozioni.count }] do
      ImportScuolePerZonaJobSilent.perform_now(@zona.reload)
    end
  end

  test "estende i mandati attivi alla nuova zona" do
    editore = Editore.create!(editore: "EDITORE TEST WIZ")
    @account.mandati.create!(editore: editore, provincia: "YY", grado: "E")

    ImportScuolePerZonaJobSilent.perform_now(@zona)

    assert @account.mandati.exists?(editore_id: editore.id, provincia: "XX", grado: "E")
  end

  test "non accoda UpdateMieAdozioniJob ne' BackfillDirezioniJob" do
    assert_no_enqueued_jobs(only: [UpdateMieAdozioniJob, BackfillDirezioniJob]) do
      ImportScuolePerZonaJobSilent.perform_now(@zona)
    end
  end
end
