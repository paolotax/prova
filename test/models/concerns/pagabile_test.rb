require "test_helper"

class PagabileTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
           :libri, :categorie, :editori, :righe, :documento_righe

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @documento = documenti(:fattura_uno) # totale 200000
  end

  teardown do
    Current.reset
  end

  test "mark_pagato salda il residuo in un colpo" do
    @documento.mark_pagato(tipo_pagamento: "contanti")

    assert @documento.pagato?
    assert_not @documento.parzialmente_pagato?
    assert_equal 1, @documento.pagamenti.count
    assert_equal 200000, @documento.pagamenti.first.importo_cents
    assert_equal 0, @documento.residuo_da_pagare_cents
  end

  test "mark_pagato è idempotente" do
    @documento.mark_pagato(tipo_pagamento: "contanti")
    assert_no_difference -> { Pagamento.count } do
      @documento.mark_pagato(tipo_pagamento: "contanti")
    end
  end

  test "registra_acconto! lascia il residuo e lo stato parziale" do
    @documento.registra_acconto!(importo_cents: 50000, tipo_pagamento: "bonifico")

    assert_not @documento.pagato?
    assert @documento.parzialmente_pagato?
    assert_equal 150000, @documento.residuo_da_pagare_cents
  end

  test "acconti successivi saturano il documento" do
    @documento.registra_acconto!(importo_cents: 50000)
    @documento.registra_acconto!(importo_cents: 150000)

    assert @documento.pagato?
    assert_equal 2, @documento.pagamenti.count
  end

  test "acconto oltre il residuo solleva ArgumentError" do
    @documento.registra_acconto!(importo_cents: 150000)

    assert_raises(ArgumentError) do
      @documento.registra_acconto!(importo_cents: 60000)
    end
  end

  test "tipo_pagamento_previsto fa da default per gli acconti" do
    @documento.update!(tipo_pagamento_previsto: "cedole")
    @documento.mark_pagato

    assert_equal "cedole", @documento.pagamenti.first.tipo_pagamento
    assert_equal "cedole", @documento.tipo_pagamento
  end

  test "il tipo esplicito vince sul previsto" do
    @documento.update!(tipo_pagamento_previsto: "cedole")
    @documento.registra_acconto!(importo_cents: 1000, tipo_pagamento: "contanti")

    assert_equal "contanti", @documento.pagamenti.first.tipo_pagamento
  end

  test "tipo_pagamento in lettura è quello dell'ultimo pagamento" do
    @documento.registra_acconto!(importo_cents: 1000, tipo_pagamento: "contanti", pagato_il: 2.days.ago)
    @documento.registra_acconto!(importo_cents: 1000, tipo_pagamento: "bonifico", pagato_il: 1.day.ago)

    assert_equal "bonifico", @documento.tipo_pagamento
  end

  test "documento a totale zero non è pagato da solo, lo diventa con mark" do
    doc = Documento.create!(account: accounts(:fizzy), user: users(:one),
                            causale: causali(:fattura), clientable: clienti(:cliente_fizzy),
                            numero_documento: 998, data_documento: Date.today)
    assert_not doc.pagato?

    doc.mark_pagato
    assert doc.pagato?
  end

  test "unmark_pagato distrugge un acconto specifico" do
    primo = @documento.registra_acconto!(importo_cents: 50000)
    @documento.registra_acconto!(importo_cents: 150000)

    @documento.unmark_pagato(primo)

    assert_not @documento.pagato?
    assert_equal 50000, @documento.residuo_da_pagare_cents
  end

  test "la saturazione propaga il pagamento ai figli col tipo dell'ultimo acconto" do
    figlio = documenti(:ordine_figlio) # padre: fattura_uno

    @documento.registra_acconto!(importo_cents: 50000, tipo_pagamento: "contanti")
    assert_not figlio.reload.pagato?, "l'acconto parziale non deve propagare"

    @documento.registra_acconto!(importo_cents: 150000, tipo_pagamento: "cedole")
    assert figlio.reload.pagato?, "la saturazione deve propagare"
    assert_equal "cedole", figlio.tipo_pagamento
  end

  test "pagato e consegnato insieme chiudono il documento" do
    @documento.ensure_entry! # in produzione l'entry è auto-creata alla create; le fixture no
    @documento.mark_consegnato
    @documento.mark_pagato(tipo_pagamento: "contanti")

    assert @documento.reload.closed?
  end

  test "registra_acconto! solleva ArgumentError su documento non pagabile" do
    documento = documenti(:ddt_fornitore_fizzy) # causale: carico_fornitore (gestione_pagamento: false)

    assert_raises(ArgumentError) do
      documento.registra_acconto!(importo_cents: 1000)
    end
    assert_equal 0, documento.pagamenti.count
  end

  test "auto_close_se_completo chiude un documento non pagabile appena consegnato" do
    documento = documenti(:scarico_saggi_fizzy) # causale: scarico_saggi (gestione_consegna true, gestione_pagamento false)
    documento.ensure_entry!

    documento.mark_consegnato

    assert documento.consegnato?
    assert documento.reload.closed?
  end

  test "auto_close_se_completo: con entrambe le gestioni spente mark_consegnato solleva ArgumentError e il documento non si chiude" do
    documento = documenti(:ddt_fornitore_fizzy) # causale: carico_fornitore (gestione_consegna false, gestione_pagamento false)
    documento.ensure_entry!

    assert_raises(ArgumentError) do
      documento.mark_consegnato
    end
    assert_not documento.consegnato?
    assert_not documento.reload.closed?
  end
end
