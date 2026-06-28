require "test_helper"

class UpdateScuoleCountersJobTest < ActiveJob::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    Current.account = @account
  end

  teardown do
    Current.account = nil
  end

  test "classi_count conta solo le classi attive; adozioni_count solo attive dell'anno corrente" do
    scuola = Scuola.create!(account: @account, denominazione: "Scuola Counters", provincia: "TO", grado: "E")

    attiva = scuola.classi.create!(account: @account, anno_corso: "2", sezione: "A", anno_scolastico: "202627", stato: "attiva")
    archiviata = scuola.classi.create!(account: @account, anno_corso: "5", sezione: "A", anno_scolastico: "202526", stato: "archiviata")

    # Classe attiva: una adozione dell'anno corrente (contata) + una dell'anno precedente (esclusa)
    crea_adozione(attiva, "9788810000001", "202627")
    crea_adozione(attiva, "9788810000002", "202526")
    # Adozione su classe archiviata (esclusa dal conteggio)
    crea_adozione(archiviata, "9788810000003", "202526")

    UpdateScuoleCountersJob.perform_now(@account)
    scuola.reload

    assert_equal 1, scuola.classi_count, "solo la classe attiva"
    assert_equal 1, scuola.adozioni_count, "solo l'adozione attiva dell'anno corrente"
  end

  test "classi/adozioni con anno_scolastico NULL restano contate (no-op pre-rollover)" do
    scuola = Scuola.create!(account: @account, denominazione: "Scuola Legacy", provincia: "TO", grado: "E")
    classe = scuola.classi.create!(account: @account, anno_corso: "1", sezione: "A", stato: "attiva") # anno_scolastico nil
    crea_adozione(classe, "9788810000010", nil) # adozione con anno nil come la classe

    UpdateScuoleCountersJob.perform_now(@account)
    scuola.reload

    assert_equal 1, scuola.classi_count
    assert_equal 1, scuola.adozioni_count, "NULL IS NOT DISTINCT FROM NULL ⇒ contata"
  end

  private

  def crea_adozione(classe, isbn, anno)
    Adozione.create!(
      account: @account, classe: classe, codice_isbn: isbn,
      titolo: "T #{isbn}", da_acquistare: true, anno_scolastico: anno
    )
  end
end
