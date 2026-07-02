require "test_helper"

class Adozione::ReconcilerTest < ActiveSupport::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    @scuola = @account.scuole.create!(codice_ministeriale: "XXEE00001A",
      provincia: "XX", comune: "TESTVILLE", denominazione: "Plesso Reconcile",
      tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
  end

  # Righe sorgente con codice sintetico "XX...": non collidono con le fixture
  # new_adozioni condivise, e la provincia "XX" isola il reconcile.
  def seed_new_adozioni(rows)
    rows.each { |r| NewAdozione.create!({ tipogradoscuola: "EE" }.merge(r)) }
  end

  def reconciler(anno: "202627")
    Adozione::Reconciler.new(account: @account, provincia: "XX", anno: anno)
  end

  test "call crea le classi distinte e non duplica su re-run" do
    seed_new_adozioni([
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
    seed_new_adozioni([
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
    seed_new_adozioni([
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

  test "source mappa anno su tabella e stato" do
    assert_equal "new_adozioni", reconciler.source.table
    assert_equal "attiva", reconciler.source.stato
    src = reconciler(anno: "202526").source
    assert_equal "import_adozioni", src.table
    assert_equal "archiviata", src.stato
  end
end
