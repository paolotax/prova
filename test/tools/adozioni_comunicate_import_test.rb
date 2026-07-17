require "test_helper"

class AdozioniComunicateImportToolTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    @user = @account.users.first
    scuola = scuole(:scuola_fizzy)
    scuola.update!(codice_ministeriale: "REEE81001P")
    Current.account = @account
    classe = Classe.create!(account: @account, scuola: scuola, anno_corso: "5",
                            sezione: "A", combinazione: "", stato: "attiva",
                            anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: classe, codice_isbn: "9788883886201",
                     anno_scolastico: "202627", codicescuola: "REEE81001P", anno_corso: "5")
    Current.reset
  end

  teardown { Current.reset }

  test "importa righe strutturate e risponde col riepilogo" do
    response = MCPTools::AdozioniComunicateImport.call(
      anno_scolastico: "202627",
      editore: "TREDIECI",
      righe: [
        { "codicescuola" => "REEE81001P", "ean" => "9788883886201",
          "titolo" => "LEGGO CON TE 5", "classe" => "5", "sezioni" => "A", "alunni" => 13 },
        { "codicescuola" => "REEE99999X", "ean" => "9788883886195",
          "classe" => "4", "sezioni" => "A", "alunni" => 23 }
      ],
      server_context: { user: @user, account: @account }
    )

    payload = JSON.parse(response.content.first[:text])
    assert_equal 2, payload["importate"]
    assert_equal 1, payload["matched"]
    assert_equal 1, payload["discrepanze"].size
    assert_equal "adozione_non_trovata", payload["discrepanze"].first["stato_match"]
  end
end
