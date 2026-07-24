require "test_helper"

class AdozioniCatalogoControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole, :classi, :adozioni

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    sign_in_as(@user, @account)

    # Catalogo: due esemplari anno 1, uno anno 2, piu un duplicato di isbn (row piu vecchia).
    @vecchia = Adozione.create!(
      account: @account, classe: classi(:pa_1a),
      codice_isbn: "9788899000001", titolo: "Sussidiario Vecchio", editore: "Ed",
      disciplina: "Sussidiario", anno_corso: "1", anno_scolastico: "202425",
      created_at: 2.years.ago
    )
    @recente = Adozione.create!(
      account: @account, classe: classi(:pa_2a),
      codice_isbn: "9788899000001", titolo: "Sussidiario Recente", editore: "Ed",
      disciplina: "Sussidiario", anno_corso: "1", anno_scolastico: "202526",
      created_at: 1.day.ago
    )
    @religione1 = Adozione.create!(
      account: @account, classe: classi(:pa_3a),
      codice_isbn: "9788899000002", titolo: "Religione Uno", editore: "Ed2",
      disciplina: "Religione", anno_corso: "1", anno_scolastico: "202526"
    )
    @grado2 = Adozione.create!(
      account: @account, classe: classi(:pa_4a),
      codice_isbn: "9788899000003", titolo: "Grammatica Due", editore: "Ed3",
      disciplina: "Grammatica", anno_corso: "2", anno_scolastico: "202526"
    )
  end

  test "distinct per isbn: tiene la row piu recente per stesso isbn" do
    get adozioni_catalogo_index_path(anno_corso: "1", q: "Sussidiario", account_id: @account.id),
      as: :turbo_stream

    assert_response :success
    assert_match "Sussidiario Recente", response.body
    assert_no_match(/Sussidiario Vecchio/, response.body)
  end

  test "filtra per anno di corso" do
    get adozioni_catalogo_index_path(anno_corso: "1", account_id: @account.id), as: :turbo_stream

    assert_response :success
    assert_match "Sussidiario Recente", response.body
    assert_match "Religione Uno", response.body
    assert_no_match(/Grammatica Due/, response.body)
  end

  test "anno di corso come lista" do
    get adozioni_catalogo_index_path(anno_corso: "1,2", account_id: @account.id), as: :turbo_stream

    assert_response :success
    assert_match "Grammatica Due", response.body
  end

  test "filtra per q su titolo" do
    get adozioni_catalogo_index_path(q: "Religione", account_id: @account.id), as: :turbo_stream

    assert_response :success
    assert_match "Religione Uno", response.body
    assert_no_match(/Grammatica Due/, response.body)
  end

  test "scoping per account: non mostra esemplari di altri account" do
    get adozioni_catalogo_index_path(q: "Fisica", account_id: @account.id), as: :turbo_stream

    assert_response :success
    # adozione_fisica_acme titolo "Fisica moderna" e in account acme
    assert_no_match(/Fisica moderna/, response.body)
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)

    Current.user = user
    Current.account = account
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
