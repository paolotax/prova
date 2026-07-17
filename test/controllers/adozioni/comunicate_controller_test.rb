require "test_helper"

class Adozioni::ComunicateControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @scuola.update!(codice_ministeriale: "REEE81001P")
    Current.account = @account

    @classe = Classe.create!(account: @account, scuola: @scuola, anno_corso: "3",
                             sezione: "B", combinazione: "", stato: "attiva",
                             anno_scolastico: "202627")
    @adozione = Adozione.create!(account: @account, classe: @classe, codice_isbn: "9788809917583",
                                 titolo: "NUOVO VIVA CRESCERE 3", anno_scolastico: "202627",
                                 codicescuola: "REEE81001P", anno_corso: "3")
    @comunicata = Adozioni::Comunicata.create!(
      account: @account, anno_scolastico: "202627", codicescuola: "REEE81001P",
      ean: "9788809917583", anno_corso: "3", sezioni: "B", alunni: 25, fonte: "excel"
    )

    Current.reset
    sign_in_as(@user, @account)
  end

  teardown { Current.reset }

  test "index mostra le righe e il riepilogo" do
    get adozioni_comunicate_path(account_id: @account.id, anno_scolastico: "202627")

    assert_response :success
    assert_match "REEE81001P", @response.body
    assert_select "table.table"
  end

  test "index filtra per stato_match" do
    Current.account = @account
    Adozioni::Comunicata.create!(
      account: @account, anno_scolastico: "202627", codicescuola: "REEE81001P",
      ean: "9791223235485", anno_corso: "4", sezioni: "A", alunni: 10,
      fonte: "excel", stato_match: "adozione_non_trovata"
    )
    Current.reset

    get adozioni_comunicate_path(account_id: @account.id, anno_scolastico: "202627", stato_match: "adozione_non_trovata")

    assert_response :success
    assert_match "9791223235485", @response.body
    assert_no_match "9788809917583", @response.body
  end

  test "rimatch rilancia il matching e redirige" do
    post adozioni_comunicate_rimatch_path(account_id: @account.id, anno_scolastico: "202627")

    assert_redirected_to adozioni_comunicate_path(anno_scolastico: "202627")
    assert_equal "matched", @comunicata.reload.stato_match
  end

  test "distribuzione forza la distribuzione multi-sezione" do
    Current.account = @account
    classe_c = Classe.create!(account: @account, scuola: @scuola, anno_corso: "3",
                              sezione: "C", combinazione: "", stato: "attiva",
                              anno_scolastico: "202627", numero_alunni: 10)
    riga_multi = Adozioni::Comunicata.create!(
      account: @account, anno_scolastico: "202627", codicescuola: "REEE81001P",
      ean: "9788809917583", anno_corso: "3", sezioni: "B,C", alunni: 45,
      fonte: "excel", stato_match: "multi_sezione"
    )
    Current.reset

    post adozioni_comunicata_distribuzione_path(riga_multi, account_id: @account.id)

    assert_redirected_to adozioni_comunicate_path(anno_scolastico: "202627")
    assert_equal "multi_sezione_distribuita", riga_multi.reload.stato_match
    assert_equal 22, classe_c.reload.numero_alunni
  end

  private

    def sign_in_as(user, account)
      session = user.sessions.create!(account: account)
      cookies[:session_token] = sign_cookie(session.token)
      Current.user = user
      Current.account = account
      Current.membership = user.memberships.find_by(account: account)
    end

    def sign_cookie(value)
      secret = Rails.application.key_generator.generate_key("signed cookie")
      ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(value)
    end
end
