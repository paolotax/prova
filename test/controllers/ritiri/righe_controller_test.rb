require "test_helper"

class Ritiri::RigheControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @riga = bolla_visione_righe(:aperta)
    sign_in_as(@user, @account)
  end

  test "update con esito=rientrato chiude la riga senza creare documento" do
    assert_no_difference -> { Documento.count } do
      patch scuola_ritiro_riga_path(scuola_id: @scuola.id, id: @riga.id, account_id: @account.id),
            params: { esito: "rientrato" }
    end
    @riga.reload
    assert_equal "rientrato", @riga.esito
    assert_not_nil @riga.processato_at
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "update con esito vuoto riapre la riga (resetta esito e processato_at)" do
    @riga.update!(esito: :rientrato, processato_at: Time.current)

    assert_no_difference ["Documento.count", "DocumentoRiga.count"] do
      patch scuola_ritiro_riga_path(scuola_id: @scuola.id, id: @riga.id, account_id: @account.id),
            params: { esito: "" }
    end
    @riga.reload
    assert_nil @riga.esito
    assert_nil @riga.processato_at
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "update con return_to=bolla redirige alla pagina bolla" do
    @riga.update!(esito: :rientrato, processato_at: Time.current)

    patch scuola_ritiro_riga_path(scuola_id: @scuola.id, id: @riga.id, account_id: @account.id),
          params: { esito: "", return_to: "bolla" }

    assert_redirected_to bolla_visione_path(@riga.bolla_visione, account_id: @account.id)
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
