require "test_helper"

class DocumentiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @documento = documenti(:one)
  end

  test "should get index" do
    get documenti_url
    assert_response :success
  end

  test "should get new" do
    get new_documento_url
    assert_response :success
  end

  test "should create documento" do
    assert_difference("Documento.count") do
      post documenti_url, params: { documento: { causale_id: @documento.causale_id, cliente_id: @documento.cliente_id, consegnato_il: @documento.consegnato_il, data_documento: @documento.data_documento, iva_cents: @documento.iva_cents, numero_documento: @documento.numero_documento, pagato_il: @documento.pagato_il, spese_cents: @documento.spese_cents, status: @documento.status, tipo_pagamento: @documento.tipo_pagamento, totale_cents: @documento.totale_cents, totale_copie: @documento.totale_copie, user_id: @documento.user_id } }
    end

    assert_redirected_to documento_url(Documento.last)
  end

  test "should show documento" do
    get documento_url(@documento)
    assert_response :success
  end

  test "should get edit" do
    get edit_documento_url(@documento)
    assert_response :success
  end

  test "should update documento" do
    patch documento_url(@documento), params: { documento: { causale_id: @documento.causale_id, cliente_id: @documento.cliente_id, consegnato_il: @documento.consegnato_il, data_documento: @documento.data_documento, iva_cents: @documento.iva_cents, numero_documento: @documento.numero_documento, pagato_il: @documento.pagato_il, spese_cents: @documento.spese_cents, status: @documento.status, tipo_pagamento: @documento.tipo_pagamento, totale_cents: @documento.totale_cents, totale_copie: @documento.totale_copie, user_id: @documento.user_id } }
    assert_redirected_to documento_url(@documento)
  end

  test "should destroy documento" do
    assert_difference("Documento.count", -1) do
      delete documento_url(@documento)
    end

    assert_redirected_to documenti_url
  end
end
