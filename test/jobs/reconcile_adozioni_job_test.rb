require "test_helper"

class ReconcileAdozioniJobTest < ActiveJob::TestCase
  fixtures :accounts, "miur/scuole"

  test "usa la coda bulk" do
    assert_equal "bulk", ReconcileAdozioniJob.new.queue_name
  end

  test "esegue il reconcile per la provincia" do
    account = accounts(:fizzy)
    scuola = account.scuole.create!(codice_ministeriale: "XXEE00002B",
      provincia: "XX", denominazione: "Plesso Job", tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
    NewAdozione.create!(tipogradoscuola: "EE", codicescuola: "XXEE00002B",
      annocorso: "1", sezioneanno: "A", combinazione: "TN", codiceisbn: "111", daacquist: "Si")

    ReconcileAdozioniJob.perform_now(account, provincia: "XX", anno: "202627")

    assert scuola.classi.exists?(anno_scolastico: "202627", anno_corso: "1", sezione: "A")
  end
end
