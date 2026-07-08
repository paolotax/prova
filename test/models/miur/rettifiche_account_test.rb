require "test_helper"

class Miur::RettificheAccountTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @account = accounts(:fizzy)
    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   completed_at: Time.current)
    # Scuola dell'account (fixture: MIIC123456, provincia MI) toccata dal diff
    @run.diff_scuole.create!(codicescuola: "MIIC123456", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 2, righe_rimosse: 1)
    # Scuola NON dell'account: deve sparire da ogni lettura
    @run.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente",
                             provincia: "TORINO", righe_aggiunte: 5, righe_rimosse: 5)
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9782222222222", sezioneanno: "B", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9781111111111", sezioneanno: "AAFM", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "-",
                            codiceisbn: "9781111111111", sezioneanno: "A", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "XXEE000099", segno: "+",
                            codiceisbn: "9789999999999", sezioneanno: "A", annocorso: "1")
    @rett = Miur::RettificheAccount.new(run: @run, account: @account)
  end

  test "scuole limitate a quelle dell'account" do
    assert_equal %w[MIIC123456], @rett.esistenti.map(&:codicescuola)
  end

  test "classificate espone veri cambi e spostamenti per scuola" do
    c = @rett.classificate.fetch("MIIC123456")
    assert_equal ["9782222222222"], c[:aggiunte].map(&:codiceisbn)
    assert_equal [], c[:rimosse]
    assert_equal 2, c[:spostate].size
  end

  test "promossa? e province_promosse: senza classi attive niente fan-out" do
    assert_not @rett.promossa?("MIIC123456")
    assert_equal [], @rett.province_promosse
  end

  test "promossa? e province_promosse: con classe attiva dell'anno la provincia account entra nel fan-out" do
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "1", sezione: "A")
    rett = Miur::RettificheAccount.new(run: @run, account: @account)
    assert rett.promossa?("MIIC123456")
    # Provincia in formato ACCOUNT ("MI" dalla scuola), NON MIUR ("MILANO")
    assert_equal ["MI"], rett.province_promosse
  end

  test "run_ids torna solo i run che toccano scuole dell'account" do
    altro = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                    completed_at: Time.current)
    altro.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente")

    ids = Miur::RettificheAccount.run_ids(@account)
    assert_includes ids, @run.id
    assert_not_includes ids, altro.id
  end

  test "esistenti ordinate: promosse prima, poi veri cambi desc" do
    Scuola.create!(account: @account, denominazione: "Seconda", codice_ministeriale: "MIEE000002",
                   comune: "Milano", provincia: "MI", grado: "E", stato: "attiva")
    @run.diff_scuole.create!(codicescuola: "MIEE000002", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 9, righe_rimosse: 0)
    9.times do |i|
      @run.diff_righe.create!(codicescuola: "MIEE000002", segno: "+",
                              codiceisbn: "97800000000#{i}0", sezioneanno: "A", annocorso: "1")
    end
    # MIIC123456 promossa (1 vero cambio), MIEE000002 no (9 veri cambi):
    # la promossa vince comunque l'ordinamento.
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "2", sezione: "A")
    rett = Miur::RettificheAccount.new(run: @run, account: @account)
    assert_equal %w[MIIC123456 MIEE000002], rett.esistenti.map(&:codicescuola)
  end
end
