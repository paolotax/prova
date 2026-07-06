require "test_helper"

class Adozione::ReconcilerTest < ActiveSupport::TestCase
  # miur/scuole fissa Miur.anno_corrente = "202627" (max anno_scolastico in
  # anagrafe): senza queste righe anno_corrente sarebbe nil e lo stato derivato
  # collasserebbe sempre a "archiviata".
  fixtures :accounts, "miur/scuole"

  setup do
    @account = accounts(:fizzy)
    @scuola = @account.scuole.create!(codice_ministeriale: "XXEE00001A",
      provincia: "XX", comune: "TESTVILLE", denominazione: "Plesso Reconcile",
      tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
  end

  # Righe sorgente con codice sintetico "XX...": non collidono con le fixture
  # miur/adozioni condivise, e la provincia "XX" isola il reconcile. anno_scolastico
  # esplicito: deve corrispondere a una partizione esistente di miur_adozioni.
  def seed_miur(rows, anno: "202627")
    rows.each do |r|
      Miur::Adozione.create!({ tipogradoscuola: "EE", anno_scolastico: anno }.merge(r))
    end
  end

  def reconciler(anno: "202627")
    Adozione::Reconciler.new(account: @account, provincia: "XX", anno: anno)
  end

  test "call crea le classi distinte e non duplica su re-run" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN", codiceisbn: "111", daacquist: "Si" },
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN", codiceisbn: "222", daacquist: "Si" },
      { codicescuola: "XXEE00001A", annocorso: "2", sezioneanno: "B", combinazione: "TN", codiceisbn: "333", daacquist: "No" }
    ])

    assert_difference -> { @scuola.classi.where(anno_scolastico: "202627").count }, 2 do
      reconciler.call
    end
    c = @scuola.classi.find_by(anno_scolastico: "202627", anno_corso: "1", sezione: "A")
    assert_equal "attiva", c.stato
    assert_equal "XXEE00001A", c.codice_ministeriale_origine

    # idempotente
    assert_no_difference -> { @scuola.classi.count } do
      reconciler.call
    end
  end

  test "call archivia le classi attive non piu in sorgente (solo 202627)" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN", codiceisbn: "111", daacquist: "Si" }
    ])
    # classe attiva non presente in sorgente
    orfana = @account.classi.create!(scuola: @scuola, anno_scolastico: "202627",
      anno_corso: "5", sezione: "Z", stato: "attiva",
      codice_ministeriale_origine: "XXEE00001A", classe_origine: "5", sezione_origine: "Z")

    reconciler.call
    assert_equal "archiviata", orfana.reload.stato
    assert_equal "attiva", @scuola.classi.find_by(anno_corso: "1", sezione: "A").stato
  end

  test "call riattiva una classe archiviata che ricompare in sorgente" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN", codiceisbn: "111", daacquist: "Si" }
    ])
    ricomparsa = @account.classi.create!(scuola: @scuola, anno_scolastico: "202627",
      anno_corso: "1", sezione: "A", combinazione: "TN", stato: "archiviata",
      codice_ministeriale_origine: "XXEE00001A", classe_origine: "1", sezione_origine: "A")

    assert_no_difference -> { @scuola.classi.count } do   # riattiva, non duplica
      reconciler.call
    end
    assert_equal "attiva", ricomparsa.reload.stato
  end

  test "call crea snapshot adozioni con anno_scolastico+codicescuola, idempotente" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "111", daacquist: "Si", nuovaadoz: "Si", consigliato: "No",
        titolo: "Libro Uno", editore: "Giunti", prezzo: "12,50" },
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "222", daacquist: "No", titolo: "Libro Due", editore: "Giunti", prezzo: "n.d." }
    ])

    assert_difference -> { @account.adozioni.where(anno_scolastico: "202627").count }, 2 do
      reconciler.call
    end
    a = @account.adozioni.find_by(codice_isbn: "111", anno_scolastico: "202627")
    assert_equal "XXEE00001A", a.codicescuola
    assert a.da_acquistare
    assert a.nuova_adozione
    assert_not a.consigliato
    assert_equal 1250, a.prezzo_cents

    b = @account.adozioni.find_by(codice_isbn: "222", anno_scolastico: "202627")
    assert_equal 0, b.prezzo_cents   # prezzo non numerico -> 0, non crash

    assert_no_difference -> { @account.adozioni.where(anno_scolastico: "202627").count } do
      reconciler.call
    end
  end

  test "call rimuove le adozioni dell'anno non piu in sorgente" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
    ])
    reconciler.call
    classe = @scuola.classi.find_by(anno_corso: "1", sezione: "A")
    orfana = @account.adozioni.create!(classe: classe, codice_isbn: "999",
      anno_scolastico: "202627", codicescuola: "XXEE00001A", anno_corso: "1", da_acquistare: true)

    reconciler.call
    assert_nil Adozione.find_by(id: orfana.id)
    assert @account.adozioni.exists?(codice_isbn: "111", anno_scolastico: "202627")
  end

  test "call NON rimuove orfane con dati utente (note, copie)" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
    ])
    reconciler.call
    classe = @scuola.classi.find_by(anno_corso: "1", sezione: "A")
    con_note = @account.adozioni.create!(classe: classe, codice_isbn: "888",
      anno_scolastico: "202627", codicescuola: "XXEE00001A", anno_corso: "1", note: "vista a scuola")
    con_copie = @account.adozioni.create!(classe: classe, codice_isbn: "777",
      anno_scolastico: "202627", codicescuola: "XXEE00001A", anno_corso: "1", numero_copie: 3)

    reconciler.call
    assert Adozione.exists?(id: con_note.id)
    assert Adozione.exists?(id: con_copie.id)
  end

  test "call end-to-end aggiorna i counter della scuola" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "111", daacquist: "Si", prezzo: "10,00" },
      { codicescuola: "XXEE00001A", annocorso: "2", sezioneanno: "B", combinazione: "TN",
        codiceisbn: "222", daacquist: "Si", prezzo: "10,00" }
    ])
    reconciler.call
    @scuola.reload
    assert_equal 2, @scuola.classi_count
    assert_equal 2, @scuola.adozioni_count
  end

  test "call archivia le attive di anni precedenti prima di creare il corrente" do
    # scuola non ancora promossa: stessa tupla attiva sul 202526 — l'indice
    # unico parziale sulle attive NON include anno_scolastico
    vecchia = @account.classi.create!(scuola: @scuola, anno_scolastico: "202526",
      anno_corso: "1", sezione: "A", combinazione: "TN", stato: "attiva",
      codice_ministeriale_origine: "XXEE00001A", classe_origine: "1", sezione_origine: "A")
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
    ])

    reconciler.call

    assert_equal "archiviata", vecchia.reload.stato
    nuova = @scuola.classi.find_by(anno_scolastico: "202627", anno_corso: "1", sezione: "A")
    assert_equal "attiva", nuova.stato
  end

  test "call NON archivia le classi di scuole assenti dalla sorgente corrente" do
    # scuola in attesa del MIUR (rilascio cumulativo): niente righe in miur_adozioni.
    # Le sue classi vecchie restano attive, altrimenti sparisce dalla panoramica
    # (con_adozioni? richiede adozioni_count > 0 o presenza nel MIUR)
    in_attesa = @account.scuole.create!(codice_ministeriale: "XXEE00009Z",
      provincia: "XX", denominazione: "In Attesa", tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
    vecchia = @account.classi.create!(scuola: in_attesa, anno_scolastico: "202526",
      anno_corso: "3", sezione: "C", stato: "attiva",
      codice_ministeriale_origine: "XXEE00009Z", classe_origine: "3", sezione_origine: "C")
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
    ])

    reconciler.call

    assert_equal "attiva", vecchia.reload.stato
  end

  # Lo stato deriva dall'anno: corrente (== Miur.anno_corrente) → attiva,
  # passato → archiviata. Stessa tabella miur_adozioni, filtrata per anno.
  test "stato deriva dall'anno corrente vs passato" do
    assert_equal "attiva", reconciler.stato
    assert_equal "archiviata", reconciler(anno: "202526").stato
  end

  test "call su anno passato crea classi/adozioni archiviate, filtrando per anno" do
    seed_miur([
      { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "555", daacquist: "Si", prezzo: "10,00" }
    ], anno: "202526")

    reconciler(anno: "202526").call

    classe = @scuola.classi.find_by(anno_scolastico: "202526", anno_corso: "1", sezione: "A")
    assert_equal "archiviata", classe.stato
    ad = @account.adozioni.find_by(codice_isbn: "555", anno_scolastico: "202526")
    assert_equal "202526", ad.anno_scolastico
    # il filtro anno isola le partizioni: nessuna classe/adozione 202627 creata
    assert_empty @scuola.classi.where(anno_scolastico: "202627")
    assert_not @account.adozioni.exists?(anno_scolastico: "202627")
  end
end
