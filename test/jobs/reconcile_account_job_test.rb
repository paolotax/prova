require "test_helper"

class ReconcileAccountJobTest < ActiveJob::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    @account.scuole.create!(codice_ministeriale: "XXEE1", provincia: "XX",
      denominazione: "Scuola XX", grado: "E")
    @account.scuole.create!(codice_ministeriale: "YYEE1", provincia: "YY",
      denominazione: "Scuola YY", grado: "E")
  end

  test "fa fan-out per provincia distinta x entrambi gli anni" do
    # dai dati (fixtures comprese), non hardcoded: resta stabile se le fixtures cambiano
    province = @account.scuole.where.not(provincia: [nil, ""]).distinct.pluck(:provincia)

    assert_enqueued_jobs province.size * 2, only: ReconcileAdozioniJob do
      ReconcileAccountJob.perform_now(@account)
    end
  end

  test "account#reconcile_adozioni_later accoda l'orchestratore" do
    assert_enqueued_with job: ReconcileAccountJob, args: [@account] do
      @account.reconcile_adozioni_later
    end
  end
end
