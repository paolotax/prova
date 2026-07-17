require "test_helper"

class Imports::AdozioniComunicateProcessorTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @account = accounts(:fizzy)
    Current.account = @account
    @scuola = Scuola.create!(account: @account, denominazione: "PRIMARIA TEST PROCESSOR",
                             codice_ministeriale: "TESTPROC01")
    classe = Classe.create!(account: @account, scuola: @scuola, anno_corso: "3",
                            sezione: "B", combinazione: "", stato: "attiva",
                            anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: classe, codice_isbn: "9788809917583",
                     anno_scolastico: "202627", codicescuola: "TESTPROC01", anno_corso: "3")
  end

  teardown { Current.reset }

  test "importa il tracciato Giunti e matcha" do
    path = crea_xlsx([
      ["011302200T", "202627", "TESTPROC01", "S. PROSPERO", "VIA ALLENDE 3", "42100",
       "REGGIO NELL'EMILIA", "RE", "A0650", "E0650", "9788809917583",
       "NUOVO VIVA CRESCERE CL. 3", "3", "B", "25"]
    ])

    processor = Imports::AdozioniComunicateProcessor.new(
      path, nil, metadata: { "anno_scolastico" => "202627" }, account: @account
    ).call

    assert processor.success?, processor.errors.inspect
    assert_equal 1, processor.imported_count
    assert_equal "matched", Adozioni::Comunicata.sole.stato_match
  end

  private

  HEADER = ["Cod. Agente", "Anno", "CodMinisteriale", "Descrizione", "Indirizzo", "CAP",
            "Comune", "Provincia", "Cod. Sc.", "Editore", "Ean", "Titolo",
            "Classe", "Sezione", "Alunni"].freeze

  def crea_xlsx(rows)
    require "caxlsx"
    path = Rails.root.join("tmp", "test_adozioni_comunicate.xlsx").to_s
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Foglio1") do |sheet|
      sheet.add_row HEADER
      rows.each { |row| sheet.add_row row }
    end
    package.serialize(path)
    path
  end
end
