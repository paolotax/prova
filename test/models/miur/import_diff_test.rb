require "test_helper"

class Miur::ImportDiffTest < ActiveSupport::TestCase
  ANNO = "202627".freeze
  STG  = "miur_adozioni_stg_test".freeze

  setup do
    @conn = ActiveRecord::Base.connection
    @conn.execute("DROP TABLE IF EXISTS #{STG}")
    @conn.execute("CREATE TABLE #{STG} (LIKE miur_adozioni INCLUDING DEFAULTS)")
    @conn.execute("ALTER TABLE #{STG} ALTER COLUMN id SET DEFAULT nextval('miur_adozioni_id_seq')")
    Miur::Scuola.create!(anno_scolastico: ANNO, codice_scuola: "MOEE000001",
                         provincia: "MODENA", tipo_scuola: "SCUOLA PRIMARIA")
  end

  teardown do
    @conn.execute("DROP TABLE IF EXISTS #{STG}")
  end

  test "classifica esistente/nuova/sparita e persiste rollup + dettaglio" do
    # vecchia partizione: scuola A con 2 righe, scuola C (sparirà)
    crea_vecchia("MOEE000001", "9781111111111")
    crea_vecchia("MOEE000001", "9782222222222")
    crea_vecchia("MOEE000003", "9783333333333")
    # staging: scuola A perde la 222 e guadagna la 444; scuola B è nuova
    crea_staging("MOEE000001", "9781111111111")
    crea_staging("MOEE000001", "9784444444444")
    crea_staging("MOEE000002", "9785555555555")

    diff = Miur::ImportDiff.new(anno: ANNO, staging: STG)
    diff.calcola
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: ANNO)
    diff.persisti(run)

    per_categoria = run.diff_scuole.group_by(&:categoria)
    assert_equal %w[MOEE000001], per_categoria["esistente"].map(&:codicescuola)
    assert_equal %w[MOEE000002], per_categoria["nuova"].map(&:codicescuola)
    assert_equal %w[MOEE000003], per_categoria["sparita"].map(&:codicescuola)

    esistente = per_categoria["esistente"].first
    assert_equal 1, esistente.righe_aggiunte   # la 444
    assert_equal 1, esistente.righe_rimosse    # la 222
    assert_equal "MODENA", esistente.provincia # da miur_scuole

    # dettaglio SOLO per la scuola esistente
    assert_equal %w[MOEE000001], run.diff_righe.distinct.pluck(:codicescuola)
    assert_equal ["9784444444444"], run.diff_righe.aggiunte.pluck(:codiceisbn)
    assert_equal ["9782222222222"], run.diff_righe.rimosse.pluck(:codiceisbn)
  end

  test "senza partizione vecchia (primo import anno) il diff si salta" do
    # anno senza partizione: to_regclass torna NULL
    diff = Miur::ImportDiff.new(anno: "209900", staging: STG)
    diff.calcola
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "209900")
    diff.persisti(run)
    assert_not run.diff?
  end

  test "senza differenze non persiste nulla" do
    crea_vecchia("MOEE000001", "9781111111111")
    crea_staging("MOEE000001", "9781111111111")

    diff = Miur::ImportDiff.new(anno: ANNO, staging: STG)
    diff.calcola
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: ANNO)
    diff.persisti(run)
    assert_not run.diff?
  end

  private

  def crea_vecchia(codicescuola, isbn)
    Miur::Adozione.create!(anno_scolastico: ANNO, codicescuola: codicescuola,
                           codiceisbn: isbn, annocorso: "1", sezioneanno: "A",
                           combinazione: "X", disciplina: "ITALIANO",
                           tipogradoscuola: "EE", titolo: "TITOLO #{isbn}")
  end

  def crea_staging(codicescuola, isbn)
    @conn.execute(<<~SQL)
      INSERT INTO #{STG} (anno_scolastico, codicescuola, codiceisbn, annocorso,
                          sezioneanno, combinazione, disciplina, tipogradoscuola, titolo)
      VALUES ('#{ANNO}', '#{codicescuola}', '#{isbn}', '1', 'A', 'X',
              'ITALIANO', 'EE', 'TITOLO #{isbn}')
    SQL
  end
end
