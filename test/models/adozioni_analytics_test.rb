require "test_helper"

class AdozioniAnalyticsTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole, :classi

  MercatoRow = Struct.new(:grado, :disciplina, :anno_corso, :codice_isbn, keyword_init: true)

  setup do
    Stats::Calcolo144.reset!
    @account = accounts(:fizzy)
    @scuola  = scuole(:scuola_fizzy)
    @classe  = classi(:prima_a_fizzy)
    @analytics = AdozioniAnalytics.new(account: @account, scuola_ids: [@scuola.id])
  end

  def crea_adozione(anno:, isbn:, disciplina:, classe: @classe, **attrs)
    Adozione.create!(
      account: @account, classe: classe, anno_scolastico: anno,
      codice_isbn: isbn, disciplina: disciplina,
      titolo: "Libro #{isbn}", editore: "Editore Test",
      da_acquistare: true, mia: true, **attrs
    )
  end

  test "anno_corrente is the latest annata in scope" do
    crea_adozione(anno: "202526", isbn: "9781111111111", disciplina: "ITALIANO")
    crea_adozione(anno: "202627", isbn: "9782222222222", disciplina: "ITALIANO")

    assert_equal "202627", @analytics.anno_corrente
  end

  test "adozioni defaults to a single annata, never a mix" do
    crea_adozione(anno: "202526", isbn: "9781111111111", disciplina: "ITALIANO")
    crea_adozione(anno: "202627", isbn: "9782222222222", disciplina: "ITALIANO")

    rows = @analytics.adozioni
    assert rows.any?
    assert rows.all? { |r| r.titolo != "Libro 9781111111111" },
           "l'annata 202526 non deve comparire nel default"

    rows_vecchie = @analytics.adozioni(anno_scolastico: "202526")
    assert rows_vecchie.any? { |r| r.titolo == "Libro 9781111111111" }
    assert rows_vecchie.none? { |r| r.titolo == "Libro 9782222222222" }
  end

  test "sezioni_pesate halves fascicoli AMBITO and keeps unico at 1" do
    crea_adozione(anno: "202627", isbn: "9783333333333",
                  disciplina: "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)")
    crea_adozione(anno: "202627", isbn: "9784444444444",
                  disciplina: "SUSSIDIARIO DELLE DISCIPLINE")

    rows = @analytics.adozioni.index_by(&:disciplina)

    ambito = rows["SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)"]
    unico  = rows["SUSSIDIARIO DELLE DISCIPLINE"]
    assert_equal 1, ambito.sezioni_count
    assert_equal 0.5, ambito.sezioni_pesate.to_f
    assert_equal 17, ambito.copie_stimate, "le copie restano fisiche, non pesate"
    assert_equal 1.0, unico.sezioni_pesate.to_f
  end

  test "national_market_totals filters by anno and weighs fascicoli" do
    NewAdozione.create!(
      anno_scolastico: "202627", codicescuola: "TESTXX001", tipogradoscuola: "EE",
      disciplina: "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)", annocorso: "4",
      sezioneanno: "A", combinazione: "SCUOLA PRIMARIA", codiceisbn: "9785555555555", daacquist: "Si"
    )
    NewAdozione.create!(
      anno_scolastico: "202526", codicescuola: "TESTXX001", tipogradoscuola: "EE",
      disciplina: "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)", annocorso: "4",
      sezioneanno: "A", combinazione: "SCUOLA PRIMARIA", codiceisbn: "9785555555555", daacquist: "Si"
    )
    ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW mercato_nazionale_mercati")

    rows = [MercatoRow.new(grado: "E", anno_corso: "4",
                           disciplina: "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)")]
    key = ["E", "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)", "4"]

    totals = @analytics.national_market_totals(rows, anno_scolastico: "202627")
    assert_equal 0.5, totals[key], "una sezione di fascicolo AMBITO pesa 0.5"

    assert_empty @analytics.national_market_totals(rows, anno_scolastico: "209900")
    assert_empty @analytics.national_market_totals(rows, anno_scolastico: nil)
  end
end
