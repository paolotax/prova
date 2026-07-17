require "test_helper"

class Adozioni::Comunicate::MatcherTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @account = accounts(:fizzy)
    Current.account = @account
    @scuola = Scuola.create!(account: @account, denominazione: "PRIMARIA TEST MATCHER",
                             codice_ministeriale: "TESTMATCH01")
    @classe_3b = crea_classe("3", "B")
    @adozione = Adozione.create!(
      account: @account, classe: @classe_3b, codice_isbn: "9788809917583",
      titolo: "NUOVO VIVA CRESCERE 3", anno_scolastico: "202627",
      codicescuola: "TESTMATCH01", anno_corso: "3"
    )
  end

  teardown { Current.reset }

  def crea_classe(anno_corso, sezione, numero_alunni: nil)
    Classe.create!(account: @account, scuola: @scuola, anno_corso:, sezione:,
                   combinazione: "", stato: "attiva", anno_scolastico: "202627",
                   numero_alunni:)
  end

  def crea_comunicata(overrides = {})
    Adozioni::Comunicata.create!({
      account: @account, anno_scolastico: "202627", codicescuola: "TESTMATCH01",
      ean: "9788809917583", anno_corso: "3", sezioni: "B", alunni: 25, fonte: "mcp"
    }.merge(overrides))
  end

  test "matched: aggancia adozione e classe e scrive numero_alunni" do
    riga = crea_comunicata
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "matched", riga.reload.stato_match
    assert_equal @adozione, riga.adozione
    assert_equal @classe_3b, riga.classe
    assert_equal 25, @classe_3b.reload.numero_alunni
  end

  test "matched su altra sezione della stessa scuola" do
    classe_3c = crea_classe("3", "C")
    riga = crea_comunicata(sezioni: "C", alunni: 18)
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "matched", riga.reload.stato_match
    assert_equal classe_3c, riga.classe
    assert_equal 18, classe_3c.reload.numero_alunni
  end

  test "classe_non_trovata quando la sezione comunicata non esiste" do
    riga = crea_comunicata(sezioni: "Z")
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "classe_non_trovata", riga.reload.stato_match
    assert_equal @adozione, riga.adozione
    assert_nil riga.classe
  end

  test "adozione_non_trovata quando ean non corrisponde" do
    riga = crea_comunicata(ean: "9791223235485")
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "adozione_non_trovata", riga.reload.stato_match
    assert_nil riga.adozione
  end

  test "multi_sezione_distribuita: divide equamente quando tutte le classi esistono e sono vuote" do
    crea_classe("3", "A")
    crea_classe("3", "C")
    riga = crea_comunicata(sezioni: "A,B,C", alunni: 69)
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "multi_sezione_distribuita", riga.reload.stato_match
    assert_equal [23, 23, 23],
      Classe.where(scuola: @scuola, anno_corso: "3").order(:sezione).pluck(:numero_alunni)
  end

  test "multi_sezione resta da rivedere se una classe ha gia numero_alunni" do
    crea_classe("3", "A", numero_alunni: 20)
    riga = crea_comunicata(sezioni: "A,B", alunni: 45)
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "multi_sezione", riga.reload.stato_match
    assert_equal @adozione, riga.adozione
  end

  test "distribuisci! forza la distribuzione sovrascrivendo" do
    crea_classe("3", "A", numero_alunni: 20)
    riga = crea_comunicata(sezioni: "A,B", alunni: 45)
    Adozioni::Comunicate::Matcher.new(riga).match!
    assert Adozioni::Comunicate::Matcher.new(riga.reload).distribuisci!

    assert_equal "multi_sezione_distribuita", riga.reload.stato_match
    assert_equal [23, 22],
      Classe.where(scuola: @scuola, anno_corso: "3", sezione: %w[A B]).order(:sezione).pluck(:numero_alunni)
  end

  test "rimatch! riesegue il matching su tutte le righe dell'anno" do
    riga = crea_comunicata(sezioni: "D")
    Adozioni::Comunicate::Matcher.new(riga).match!
    assert_equal "classe_non_trovata", riga.reload.stato_match

    crea_classe("3", "D")
    Adozioni::Comunicate::Matcher.rimatch!(account: @account, anno_scolastico: "202627")
    assert_equal "matched", riga.reload.stato_match
  end
end
