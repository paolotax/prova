require "test_helper"

class Adozioni::Comunicate::ImporterTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @account = accounts(:fizzy)
    Current.account = @account
    @scuola = scuole(:scuola_fizzy)
    @scuola.update!(codice_ministeriale: "REEE81001P")
    @classe = Classe.create!(account: @account, scuola: @scuola, anno_corso: "3",
                             sezione: "B", combinazione: "", stato: "attiva",
                             anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: @classe, codice_isbn: "9788809917583",
                     anno_scolastico: "202627", codicescuola: "REEE81001P", anno_corso: "3")
  end

  teardown { Current.reset }

  def importer(fonte: "mcp")
    Adozioni::Comunicate::Importer.new(account: @account, anno_scolastico: "202627",
                                       fonte: fonte, editore: "GIUNTI SCUOLA")
  end

  test "crea la riga, normalizza ean e lancia il matching" do
    importer.import_rows([{ codicescuola: "reee81001p", ean: "978-88-0991-7583",
                            classe: "3", sezioni: "B", alunni: 25, titolo: "VIVA CRESCERE" }])

    riga = Adozioni::Comunicata.sole
    assert_equal "REEE81001P", riga.codicescuola
    assert_equal "9788809917583", riga.ean
    assert_equal "matched", riga.stato_match
    assert_equal "GIUNTI SCUOLA", riga.editore
    assert_equal 25, @classe.reload.numero_alunni
  end

  test "idempotente: reimport aggiorna alunni senza duplicare" do
    2.times do |i|
      importer.import_rows([{ codicescuola: "REEE81001P", ean: "9788809917583",
                              classe: "3", sezioni: "B", alunni: 20 + i }])
    end

    assert_equal 1, Adozioni::Comunicata.count
    assert_equal 21, Adozioni::Comunicata.sole.alunni
  end

  test "accetta campo combinato classi_sezioni" do
    importer.import_rows([{ codicescuola: "REEE81001P", ean: "9788809917583",
                            classi_sezioni: "3B", alunni: 25 }])

    riga = Adozioni::Comunicata.sole
    assert_equal "3", riga.anno_corso
    assert_equal "B", riga.sezioni
  end

  test "classe numerica da Roo (3.0) diventa stringa 3" do
    importer.import_rows([{ codicescuola: "REEE81001P", ean: "9788809917583",
                            classe: 3.0, sezioni: "B", alunni: 25 }])
    assert_equal "3", Adozioni::Comunicata.sole.anno_corso
  end

  test "riga invalida finisce negli errori senza bloccare le altre" do
    result = importer.import_rows([
      { codicescuola: "REEE81001P", ean: "9788809917583", classe: "", sezioni: "B", alunni: 25 },
      { codicescuola: "REEE81001P", ean: "9788809917583", classe: "3", sezioni: "B", alunni: 25 }
    ])

    assert_equal 1, result.errori.size
    assert_equal 1, result.importate
  end

  test "riepilogo conta matched e discrepanze" do
    result = importer.import_rows([
      { codicescuola: "REEE81001P", ean: "9788809917583", classe: "3", sezioni: "B", alunni: 25 },
      { codicescuola: "REEE81001P", ean: "9791223235485", classe: "4", sezioni: "A", alunni: 10 }
    ])

    riepilogo = result.riepilogo
    assert_equal 2, riepilogo[:importate]
    assert_equal 1, riepilogo[:matched]
    assert_equal 1, riepilogo[:discrepanze].size
    assert_equal "adozione_non_trovata", riepilogo[:discrepanze].first[:stato_match]
  end
end
