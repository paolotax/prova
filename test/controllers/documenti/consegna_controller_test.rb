require "test_helper"

module Documenti
  class ConsegnaControllerTest < ActionDispatch::IntegrationTest
    fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
             :libri, :categorie, :editori, :righe, :documento_righe

    setup do
      @account = accounts(:fizzy)
      @user = users(:one)
      @documento = documenti(:fattura_uno) # 1 riga da 20 copie
      @documento_riga = documento_righe(:dr_fattura_uno)

      sign_in_as(@user, @account)
    end

    test "create senza righe consegna tutto il residuo" do
      post documento_consegna_path(account_id: @account.id, documento_id: @documento.id, format: :json), params: { consegnato_il: "2026-07-14" }

      assert_response :success
      assert @documento.reload.consegnato?
      assert_equal 20, @documento.copie_consegnate
    end

    test "create con righe fa una consegna parziale" do
      post documento_consegna_path(account_id: @account.id, documento_id: @documento.id, format: :json),
        params: { consegnato_il: "2026-07-14", righe: { @documento_riga.id.to_s => "12" } }

      assert_response :success
      documento = Documento.find(@documento.id)
      assert documento.parzialmente_consegnato?
      assert_equal 12, documento.copie_consegnate
      assert_equal 8, documento.copie_residue_da_consegnare
    end

    test "create con righe_libro risolve isbn in documento_riga (CLI)" do
      post documento_consegna_path(account_id: @account.id, documento_id: @documento.id, format: :json),
        params: { righe_libro: { "9788800000001" => "12" } }

      assert_response :success
      documento = Documento.find(@documento.id)
      assert documento.parzialmente_consegnato?
      assert_equal 8, documento.copie_residue_da_consegnare
    end

    test "create via turbo stream aggiorna meta, dialog e riepiloghi" do
      post documento_consegna_path(account_id: @account.id, documento_id: @documento.id),
        params: { consegnato_il: "2026-07-14", righe: { @documento_riga.id.to_s => "12" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      assert_response :success
      assert_match %(target="meta_documento_#{@documento.id}"), response.body
      assert_match %(target="gestione_dialog_documento_#{@documento.id}"), response.body
      assert_match %(target="riepiloghi_documento_#{@documento.id}"), response.body
      assert_match "Da consegnare (8 cp)", response.body
    end

    test "destroy con consegna_id annulla quella consegna, non l'ultima" do
      prima = @documento.consegna_parziale!({ @documento_riga.id => 12 }, user: @user)
      @documento.consegna_parziale!({ @documento_riga.id => 8 }, user: @user)

      delete documento_consegna_path(account_id: @account.id, documento_id: @documento.id, format: :json), params: { consegna_id: prima.id }

      assert_response :success
      documento = Documento.find(@documento.id)
      assert_equal 8, documento.copie_consegnate
      assert_not documento.consegnato?
    end

    test "destroy senza consegna_id annulla l'ultima consegna" do
      @documento.consegna_parziale!({ @documento_riga.id => 12 }, user: @user)
      ultima = @documento.consegna_parziale!({ @documento_riga.id => 8 }, user: @user)

      delete documento_consegna_path(account_id: @account.id, documento_id: @documento.id, format: :json)

      assert_nil Consegna.find_by(id: ultima.id)
      assert_equal 12, Documento.find(@documento.id).copie_consegnate
    end

    test "show documento parziale mostra storico e pannello parziale" do
      @documento.consegna_parziale!({ @documento_riga.id => 12 }, user: @user)

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "input[name=?]", "righe[#{@documento_riga.id}]"
      assert_match "Consegnate <strong>12</strong> di <strong>20</strong> copie", response.body
    end

    test "show documento con consegne mostra il riepilogo con residuo e consegnate" do
      @documento.consegna_parziale!({ @documento_riga.id => 12 }, user: @user)

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Da consegnare \(8 cp\)/
      assert_select "h3", text: /Consegnate \(12 cp\)/
      assert_select "a[href*=?]", "consegna.pdf"
    end

    test "show documento senza consegne non mostra il riepilogo" do
      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Da consegnare/, count: 0
      assert_select "h3", text: /Consegnate/, count: 0
    end

    test "show documento consegnato tutto in una volta non mostra il riepilogo" do
      @documento.mark_consegnato(user: @user)

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Consegnate/, count: 0
    end

    test "show documento saturato con due consegne mostra il riepilogo" do
      @documento.consegna_parziale!({ @documento_riga.id => 12 }, user: @user)
      @documento.consegna_parziale!({ @documento_riga.id => 8 }, user: @user)

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Consegnate \(20 cp\)/
      assert_select "h3", text: /Da consegnare/, count: 0
    end

    test "consegna.pdf genera la distinta" do
      @documento.consegna_parziale!({ @documento_riga.id => 12 }, user: @user)

      get documento_consegna_path(account_id: @account.id, documento_id: @documento.id, format: :pdf)

      assert_response :success
      assert_equal "application/pdf", response.media_type
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
      key_generator = Rails.application.key_generator
      secret = key_generator.generate_key("signed cookie")
      verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
      verifier.generate(value)
    end
  end
end
