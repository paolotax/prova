require "test_helper"

class RitiriDocumentiControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @riga = bolla_visione_righe(:aperta)
    sign_in_as(@user, @account)
  end

  test "create genera documento Scarico Saggi e chiude le righe selezionate" do
    assert_difference -> { Documento.count } => 1,
                      -> { DocumentoRiga.count } => 1 do
      post scuola_ritiro_documenti_path(@scuola, account_id: @account.id), params: {
        causale_id: causali(:scarico_saggi).id,
        clientable_type: "Scuola",
        clientable_id: @scuola.id,
        data_documento: Date.current,
        bolla_visione_riga_ids: [@riga.id]
      }
    end
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)

    @riga.reload
    assert_equal "in_saggio", @riga.esito
    assert_not_nil @riga.processato_at
    assert_not_nil @riga.documento_riga_id
  end

  test "create con nessuna riga selezionata torna in show con flash" do
    post scuola_ritiro_documenti_path(@scuola, account_id: @account.id), params: {
      causale_id: causali(:scarico_saggi).id,
      clientable_type: "Scuola",
      clientable_id: @scuola.id,
      data_documento: Date.current,
      bolla_visione_riga_ids: []
    }
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_match(/seleziona/i, flash[:alert])
  end

  test "create con causale_id non valida ridireziona con flash di errore" do
    post scuola_ritiro_documenti_path(@scuola, account_id: @account.id), params: {
      causale_id: 999_999,
      clientable_type: "Scuola",
      clientable_id: @scuola.id,
      data_documento: Date.current,
      bolla_visione_riga_ids: [@riga.id]
    }
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_match(/causale/i, flash[:alert])
    @riga.reload
    assert_nil @riga.processato_at
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
