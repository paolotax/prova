require "test_helper"

class SaldoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    Current.account = @account
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  # --- Ricalcola ---

  test "ricalcola! calculates signed copie and importo" do
    @cliente.ricalcola_saldo!
    saldo = @cliente.saldo.reload

    # Top-level docs per cliente_fizzy:
    #   documento_fizzy: vendita (mov=1), 100000 cents, 10 copie → +
    #   fattura_uno:     fattura (mov=1), 200000 cents, 20 copie → +
    #   fattura_due:     fattura (mov=1), 150000 cents, 15 copie → +
    #   nota_credito:    nota_credito (mov=0), 30000 cents, 3 copie → -
    #   ordine_figlio:   escluso (ha documento_padre_id)
    expected_copie = 10 + 20 + 15 - 3
    expected_importo = 100000 + 200000 + 150000 - 30000

    assert_equal expected_copie, saldo.copie_da_pagare
    assert_equal expected_importo, saldo.importo_da_pagare_cents
    assert_equal expected_copie, saldo.copie_da_consegnare
    assert_equal expected_importo, saldo.importo_da_consegnare_cents
  end

  test "ricalcola! excludes documents with documento_padre_id" do
    @cliente.ricalcola_saldo!
    saldo = @cliente.saldo.reload

    # ordine_figlio (80000, 8 copie) ha documento_padre → escluso
    assert_equal 420000, saldo.importo_da_pagare_cents
    assert_equal 42, saldo.copie_da_pagare
  end

  test "ricalcola! calculates consegnare independently from pagare" do
    doc = documenti(:fattura_uno)
    doc.mark_pagato(tipo_pagamento: "contanti")

    @cliente.ricalcola_saldo!
    saldo = @cliente.saldo.reload

    # da_pagare: senza fattura_uno → 100000 + 150000 - 30000 = 220000, copie 10+15-3=22
    assert_equal 220000, saldo.importo_da_pagare_cents
    assert_equal 22, saldo.copie_da_pagare

    # da_consegnare: fattura_uno non consegnata → ancora tutto
    assert_equal 420000, saldo.importo_da_consegnare_cents
    assert_equal 42, saldo.copie_da_consegnare
  end

  test "nota credito riduce copie e importo" do
    # Senza nota credito sarebbe 450000 e 45 copie
    @cliente.ricalcola_saldo!
    saldo = @cliente.saldo.reload

    assert_equal 420000, saldo.importo_da_pagare_cents  # 450000 - 30000
    assert_equal 42, saldo.copie_da_pagare              # 45 - 3
  end

  # --- mark_pagato aggiorna saldo ---

  test "mark_pagato updates saldo automatically" do
    @cliente.ricalcola_saldo!
    importo_prima = @cliente.saldo.reload.importo_da_pagare_cents
    copie_prima = @cliente.saldo.copie_da_pagare

    doc = documenti(:fattura_uno)
    doc.mark_pagato(tipo_pagamento: "contanti")

    saldo = @cliente.saldo.reload
    assert_equal importo_prima - 200000, saldo.importo_da_pagare_cents
    assert_equal copie_prima - 20, saldo.copie_da_pagare
  end

  test "unmark_pagato updates saldo automatically" do
    doc = documenti(:fattura_uno)
    doc.mark_pagato(tipo_pagamento: "contanti")
    @cliente.ricalcola_saldo!

    importo_prima = @cliente.saldo.reload.importo_da_pagare_cents
    copie_prima = @cliente.saldo.copie_da_pagare

    doc.reload.unmark_pagato

    saldo = @cliente.saldo.reload
    assert_equal importo_prima + 200000, saldo.importo_da_pagare_cents
    assert_equal copie_prima + 20, saldo.copie_da_pagare
  end

  # --- mark_consegnato aggiorna saldo ---

  test "mark_consegnato updates saldo automatically" do
    @cliente.ricalcola_saldo!
    importo_prima = @cliente.saldo.reload.importo_da_consegnare_cents
    copie_prima = @cliente.saldo.copie_da_consegnare

    doc = documenti(:fattura_due)
    doc.mark_consegnato

    saldo = @cliente.saldo.reload
    assert_equal importo_prima - 150000, saldo.importo_da_consegnare_cents
    assert_equal copie_prima - 15, saldo.copie_da_consegnare
  end

  test "unmark_consegnato updates saldo automatically" do
    doc = documenti(:fattura_due)
    doc.mark_consegnato
    @cliente.ricalcola_saldo!

    importo_prima = @cliente.saldo.reload.importo_da_consegnare_cents
    copie_prima = @cliente.saldo.copie_da_consegnare

    doc.reload.unmark_consegnato

    saldo = @cliente.saldo.reload
    assert_equal importo_prima + 150000, saldo.importo_da_consegnare_cents
    assert_equal copie_prima + 15, saldo.copie_da_consegnare
  end

  # --- Saldabile concern ---

  test "saldo! creates saldo if not exists" do
    assert_nil @cliente.saldo

    assert_difference -> { Saldo.count }, 1 do
      @cliente.saldo!
    end

    assert_not_nil @cliente.saldo
    assert_equal @account, @cliente.saldo.account
  end

  test "saldo! returns existing saldo" do
    @cliente.saldo!
    existing = @cliente.saldo

    assert_no_difference -> { Saldo.count } do
      result = @cliente.saldo!
      assert_equal existing, result
    end
  end

  test "ricalcola_saldo! creates saldo and calculates" do
    assert_nil @cliente.saldo

    @cliente.ricalcola_saldo!

    assert_not_nil @cliente.reload.saldo
    assert @cliente.saldo.importo_da_pagare_cents > 0
    assert @cliente.saldo.copie_da_pagare > 0
  end

  # --- Documenti figli esclusi ---

  test "paying parent does not affect child exclusion" do
    @cliente.ricalcola_saldo!
    saldo_completo = @cliente.saldo.reload.importo_da_pagare_cents

    # Paga fattura_uno (padre di ordine_figlio)
    documenti(:fattura_uno).mark_pagato(tipo_pagamento: "contanti")

    saldo_dopo = @cliente.saldo.reload.importo_da_pagare_cents

    # Solo fattura_uno rimossa, ordine_figlio era già escluso
    assert_equal saldo_completo - 200000, saldo_dopo
  end

  test "saldo is zero when all top-level documents are paid and delivered" do
    Documento.where(clientable: @cliente, documento_padre_id: nil).each do |doc|
      doc.mark_pagato(tipo_pagamento: "contanti")
      doc.reload.mark_consegnato
    end

    saldo = @cliente.saldo.reload
    assert_equal 0, saldo.copie_da_pagare
    assert_equal 0, saldo.importo_da_pagare_cents
    assert_equal 0, saldo.copie_da_consegnare
    assert_equal 0, saldo.importo_da_consegnare_cents
  end
end
