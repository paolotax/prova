require "test_helper"

module MCPTools
  class DocumentiStatoTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
             :libri, :categorie, :editori, :righe, :documento_righe

    setup do
      @server_context = { user: users(:one), account: accounts(:fizzy) }
      @documento = documenti(:fattura_uno) # 1 riga da 20 copie, totale 2000 €
    end

    teardown do
      Current.reset
    end

    def call_tool(**params)
      response = DocumentiStato.call(id: @documento.id, server_context: @server_context, **params)
      JSON.parse(response.content.first[:text])
    end

    test "pagamento senza importo salda tutto" do
      result = call_tool(azione: "pagamento", tipo_pagamento: "contanti")

      assert result["pagato"]
      assert_equal 0, result["residuo_da_pagare_cents"]
      assert_equal 200000, result["pagato_cents"]
    end

    test "pagamento con importo registra un acconto" do
      result = call_tool(azione: "pagamento", importo: "200", tipo_pagamento: "bonifico")

      assert_not result["pagato"]
      assert_equal 20000, result["pagato_cents"]
      assert_equal 180000, result["residuo_da_pagare_cents"]
      assert @documento.reload.parzialmente_pagato?
    end

    test "pagamento con importo oltre il residuo torna errore" do
      result = call_tool(azione: "pagamento", importo: "9999.99")

      assert_match /oltre il residuo/, result["error"]
    end

    test "consegna senza righe consegna tutto" do
      result = call_tool(azione: "consegna")

      assert result["consegnato"]
      assert_equal 20, result["copie_consegnate"]
      assert_equal 0, result["copie_residue"]
    end

    test "consegna con righe per isbn fa una consegna parziale" do
      result = call_tool(azione: "consegna", righe: { "9788800000001" => 12 })

      assert_not result["consegnato"]
      assert_equal 12, result["copie_consegnate"]
      assert_equal 8, result["copie_residue"]
    end

    test "consegna con righe per libro_id" do
      result = call_tool(azione: "consegna", righe: { libri(:libro_fizzy).id.to_s => 5 })

      assert_equal 5, result["copie_consegnate"]
      assert_equal 15, result["copie_residue"]
    end

    test "consegna con isbn sconosciuto torna errore" do
      result = call_tool(azione: "consegna", righe: { "9799999999999" => 1 })

      assert_match /nessuna riga del documento/, result["error"]
      assert_equal 0, @documento.reload.copie_consegnate
    end
  end
end
