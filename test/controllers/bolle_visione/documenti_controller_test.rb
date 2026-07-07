require "test_helper"

class BolleVisione::DocumentiControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali, :persone

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @bolla = bolle_visione(:bv_fizzy_uno)
    @riga1 = bolla_visione_righe(:aperta)
    @riga2 = bolla_visione_righe(:aperta_due)
    @persona = persone(:persona_fizzy)
    sign_in_as(@user, @account)
  end

  test "create con selection multi-clientable crea N documenti" do
    payload = {
      causale_id: causali(:scarico_saggi).id,
      data_documento: Date.current.to_s,
      selection: { "Persona" => { @persona.id.to_s => [@riga1.id, @riga2.id] } }
    }
    assert_difference -> { Documento.count } => 1 do
      post bolla_visione_documenti_path(@bolla, account_id: @account.id), params: payload
    end
    # PK uuid: Documento.last non è "l'ultimo creato", va cercato per attributi
    documento = Documento.order(:created_at).where(clientable: @persona).last
    assert_not_nil documento
    assert_equal @persona, documento.clientable
    assert_equal 2, documento.documento_righe.count
    assert documento.consegnato?, "Scarico saggi deve essere marcato consegnato"
    assert_redirected_to bolla_visione_path(@bolla, account_id: @account.id)
  end

  test "create con selection_json (string) funziona come selection (hash)" do
    payload = {
      causale_id: causali(:scarico_saggi).id,
      data_documento: Date.current.to_s,
      selection_json: { "Persona" => { @persona.id.to_s => [@riga1.id] } }.to_json
    }
    assert_difference -> { Documento.count } => 1 do
      post bolla_visione_documenti_path(@bolla, account_id: @account.id), params: payload
    end
  end

  test "create con N classi sulla stessa riga crea N documenti raggruppati per classe" do
    classe = @bolla.scuola.classi.first || @bolla.scuola.classi.create!(anno_corso: 5, sezione: "A", account: @account)
    classe_b = @bolla.scuola.classi.create!(anno_corso: 5, sezione: "B", account: @account)
    classe_c = @bolla.scuola.classi.create!(anno_corso: 5, sezione: "C", account: @account)

    payload = {
      causale_id: causali(:scarico_saggi).id,
      data_documento: Date.current.to_s,
      selection: { "Classe" => {
        classe.id.to_s   => [@riga1.id, @riga2.id],
        classe_b.id.to_s => [@riga1.id],
        classe_c.id.to_s => [@riga1.id]
      } }
    }
    assert_difference -> { Documento.count } => 3 do
      post bolla_visione_documenti_path(@bolla, account_id: @account.id), params: payload
    end
    # PK uuid: Documento.last(3) non è "gli ultimi creati", va cercato per attributi
    docs = Documento.where(clientable_type: "Classe")
    assert_equal [classe, classe_b, classe_c].map(&:id).sort, docs.map { |d| d.clientable_id }.sort
    doc_a = docs.find { |d| d.clientable_id == classe.id }
    assert_equal 2, doc_a.documento_righe.count
  end

  test "create con selection vuota redirige con flash di errore" do
    post bolla_visione_documenti_path(@bolla, account_id: @account.id), params: {
      causale_id: causali(:scarico_saggi).id,
      data_documento: Date.current.to_s,
      selection: {}
    }
    assert_redirected_to bolla_visione_path(@bolla, account_id: @account.id)
    assert_match(/seleziona/i, flash[:alert])
  end

  test "create rollback se uno dei clientable fallisce" do
    payload = {
      causale_id: causali(:scarico_saggi).id,
      data_documento: Date.current.to_s,
      selection: {
        "Persona" => {
          @persona.id.to_s => [@riga1.id],
          "00000000-0000-0000-0000-000000000000" => [@riga2.id]
        }
      }
    }
    assert_no_difference -> { Documento.count } do
      post bolla_visione_documenti_path(@bolla, account_id: @account.id), params: payload
    end
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
