require "test_helper"

module Documenti
  class PagamentoControllerTest < ActionDispatch::IntegrationTest
    fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
             :libri, :categorie, :editori, :righe, :documento_righe

    setup do
      @account = accounts(:fizzy)
      @user = users(:one)
      @documento = documenti(:fattura_uno) # totale 2000 €

      sign_in_as(@user, @account)
    end

    test "create senza importo salda tutto il residuo" do
      post documento_pagamento_path(account_id: @account.id, documento_id: @documento.id, format: :json),
        params: { pagato_il: "2026-07-14", tipo_pagamento: "contanti" }

      assert_response :success
      documento = Documento.find(@documento.id)
      assert documento.pagato?
      assert_equal documento.totale_cents, documento.pagato_cents
    end

    test "create con importo registra un acconto" do
      post documento_pagamento_path(account_id: @account.id, documento_id: @documento.id, format: :json),
        params: { pagato_il: "2026-07-14", tipo_pagamento: "bonifico", importo: "500.50" }

      assert_response :success
      documento = Documento.find(@documento.id)
      assert documento.parzialmente_pagato?
      assert_equal 50050, documento.pagato_cents
      assert_equal documento.totale_cents - 50050, documento.residuo_da_pagare_cents
    end

    test "destroy con pagamento_id annulla quel pagamento, non l'ultimo" do
      primo = @documento.registra_acconto!(importo_cents: 50000, user: @user)
      @documento.registra_acconto!(importo_cents: 30000, user: @user)

      delete documento_pagamento_path(account_id: @account.id, documento_id: @documento.id, format: :json),
        params: { pagamento_id: primo.id }

      assert_response :success
      assert_equal 30000, Documento.find(@documento.id).pagato_cents
    end

    test "destroy senza pagamento_id annulla l'ultimo pagamento" do
      @documento.registra_acconto!(importo_cents: 50000, user: @user)
      ultimo = @documento.registra_acconto!(importo_cents: 30000, user: @user)

      delete documento_pagamento_path(account_id: @account.id, documento_id: @documento.id, format: :json)

      assert_nil Pagamento.find_by(id: ultimo.id)
      assert_equal 50000, Documento.find(@documento.id).pagato_cents
    end

    test "dialog gestione con acconto mostra storico e campo acconto" do
      @documento.registra_acconto!(importo_cents: 50000, user: @user, tipo_pagamento: "bonifico")

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "input[name=?]", "importo"
      assert_match "Bonifico", response.body
      assert_match /Pagati <strong>500,00/, response.body
    end

    test "show documento con acconto mostra il riepilogo Acconti col residuo" do
      @documento.registra_acconto!(importo_cents: 50000, user: @user, tipo_pagamento: "bonifico")

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Acconti/
      assert_match "Residuo da pagare", response.body
    end

    test "show documento pagato in unica soluzione non mostra il riepilogo Acconti" do
      @documento.mark_pagato(user: @user)

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Acconti/, count: 0
    end

    test "show documento saldato con più acconti mostra lo storico senza residuo" do
      @documento.registra_acconto!(importo_cents: 50000, user: @user)
      @documento.mark_pagato(user: @user)

      get documento_path(account_id: @account.id, id: @documento.id)

      assert_response :success
      assert_select "h3", text: /Acconti/
      assert_no_match "Residuo da pagare", response.body
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
