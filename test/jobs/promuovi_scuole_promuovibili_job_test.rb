require "test_helper"

class PromuoviScuolePromuovibiliJobTest < ActiveJob::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    @anno = "202627"
    @xx = crea_promuovibile(codice: "XXEE00001A", provincia: "XX")
    @yy = crea_promuovibile(codice: "YYEE00001A", provincia: "YY")
  end

  # Il DB di test può contenere residui in tabelle fuori dalle fixture dichiarate:
  # si asserisce sulle scuole sintetiche, non sui conteggi totali.
  test "senza provincia accoda le promozioni di tutte le province" do
    PromuoviScuolePromuovibiliJob.perform_now(@account)

    assert_includes scuole_accodate, @xx.to_global_id.to_s
    assert_includes scuole_accodate, @yy.to_global_id.to_s
  end

  test "con provincia accoda solo le promozioni di quella provincia" do
    PromuoviScuolePromuovibiliJob.perform_now(@account, provincia: "XX")

    assert_includes scuole_accodate, @xx.to_global_id.to_s
    assert_not_includes scuole_accodate, @yy.to_global_id.to_s
  end

  private

  def scuole_accodate
    enqueued_jobs.select { |j| j[:job] == ScuolaPromuoviClassiJob }
                 .map { |j| j[:args].first["_aj_globalid"] }
  end

  def crea_promuovibile(codice:, provincia:)
    scuola = @account.scuole.create!(codice_ministeriale: codice,
      provincia: provincia, comune: "TESTVILLE #{provincia}",
      denominazione: "Primaria #{provincia}", tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
    NewScuola.create!(codice_scuola: codice, anno_scolastico: @anno,
      provincia: provincia, comune: "TESTVILLE #{provincia}",
      denominazione: "PRIMARIA #{provincia}", tipo_scuola: "SCUOLA PRIMARIA")
    NewAdozione.create!(codicescuola: codice, tipogradoscuola: "EE",
      annocorso: "1", sezioneanno: "A", combinazione: "TN",
      codiceisbn: "988000000#{provincia.sum}", daacquist: "Si")
    scuola
  end
end
