require "test_helper"

class BackfillDirezioniJobTest < ActiveJob::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
  end

  test "links plesso to existing direzione" do
    direzione_import = ImportScuola.create!(
      CODICESCUOLA: "MIDIR0001",
      DENOMINAZIONESCUOLA: "Direzione Milano",
      CODICEISTITUTORIFERIMENTO: "MIDIR0001",
      PROVINCIA: "MI"
    )
    plesso_import = ImportScuola.create!(
      CODICESCUOLA: "MIPLE0001",
      DENOMINAZIONESCUOLA: "Plesso Milano A",
      CODICEISTITUTORIFERIMENTO: "MIDIR0001",
      PROVINCIA: "MI"
    )
    direzione = Scuola.create!(
      account: @account,
      import_scuola: direzione_import,
      codice_ministeriale: "MIDIR0001",
      denominazione: "Direzione Milano"
    )
    plesso = Scuola.create!(
      account: @account,
      import_scuola: plesso_import,
      codice_ministeriale: "MIPLE0001",
      denominazione: "Plesso Milano A"
    )

    BackfillDirezioniJob.perform_now(@account)

    assert_equal direzione.id, plesso.reload.direzione_id
  end

  test "creates direzione cross-provincia and links plesso" do
    cross_dir = ImportScuola.create!(
      CODICESCUOLA: "BODIR9999",
      DENOMINAZIONESCUOLA: "Direzione Bologna",
      CODICEISTITUTORIFERIMENTO: "BODIR9999",
      PROVINCIA: "BO"
    )
    plesso_cross = ImportScuola.create!(
      CODICESCUOLA: "MIPLE9999",
      DENOMINAZIONESCUOLA: "Plesso Cross",
      CODICEISTITUTORIFERIMENTO: "BODIR9999",
      PROVINCIA: "MI"
    )
    plesso = Scuola.create!(
      account: @account,
      import_scuola: plesso_cross,
      codice_ministeriale: "MIPLE9999",
      denominazione: "Plesso Cross"
    )

    assert_difference -> { @account.scuole.where(codice_ministeriale: "BODIR9999").count }, 1 do
      BackfillDirezioniJob.perform_now(@account)
    end

    plesso.reload
    direzione_creata = @account.scuole.find_by(codice_ministeriale: "BODIR9999")
    assert_equal direzione_creata.id, plesso.direzione_id
  end

  test "skips scuole without import_scuola" do
    Scuola.create!(account: @account, codice_ministeriale: "ZZZ", denominazione: "Stand-alone")

    assert_nothing_raised do
      BackfillDirezioniJob.perform_now(@account)
    end
  end

  test "noop on second run" do
    direzione_import = ImportScuola.create!(
      CODICESCUOLA: "MIDIR0002",
      DENOMINAZIONESCUOLA: "Direzione 2",
      CODICEISTITUTORIFERIMENTO: "MIDIR0002",
      PROVINCIA: "MI"
    )
    plesso_import = ImportScuola.create!(
      CODICESCUOLA: "MIPLE0002",
      DENOMINAZIONESCUOLA: "Plesso 2",
      CODICEISTITUTORIFERIMENTO: "MIDIR0002",
      PROVINCIA: "MI"
    )
    Scuola.create!(account: @account, import_scuola: direzione_import,
                   codice_ministeriale: "MIDIR0002", denominazione: "Direzione 2")
    Scuola.create!(account: @account, import_scuola: plesso_import,
                   codice_ministeriale: "MIPLE0002", denominazione: "Plesso 2")

    BackfillDirezioniJob.perform_now(@account)
    count_after_first = @account.scuole.count

    assert_no_difference -> { @account.scuole.count } do
      BackfillDirezioniJob.perform_now(@account)
    end
    assert_equal count_after_first, @account.scuole.count
  end

  test "noop when no orphan exist" do
    assert_nothing_raised do
      BackfillDirezioniJob.perform_now(@account)
    end
  end
end
