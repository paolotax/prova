require "test_helper"

module MCPTools
  class DocumentiListTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
             :libri, :categorie, :editori, :righe, :documento_righe

    setup do
      @server_context = { user: users(:one), account: accounts(:fizzy) }
    end

    teardown do
      Current.reset
    end

    def call_tool(**params)
      response = DocumentiList.call(server_context: @server_context, **params)
      JSON.parse(response.content.first[:text])
    end

    # Regressione: il where su causali con :clientable negli includes forzava
    # l'eager_load JOIN -> "Cannot eagerly load the polymorphic association"
    test "filtro causale carica il clientable polimorfico senza esplodere" do
      result = call_tool(causale: "TD01", stato: "tutti")

      documento = result["results"].find { |d| d["numero_documento"] == 100 }
      assert documento, "fattura_uno assente dai risultati"
      assert_equal "TD01", documento["causale"]
      assert_equal clienti(:cliente_fizzy).denominazione, documento["clientable_display"]
    end

    # Regressione: numero_documento è integer, l'ILIKE alzava PG::UndefinedFunction
    test "ricerca per numero documento" do
      result = call_tool(numero_documento: "100", stato: "tutti")

      assert_equal 1, result["count"]
      assert_equal 100, result["results"].first["numero_documento"]
    end

    test "numero documento con prefisso anno usa le cifre finali" do
      result = call_tool(numero_documento: "2026/100", stato: "tutti")

      assert_equal 1, result["count"]
    end

    test "search e causale combinati" do
      result = call_tool(search: clienti(:cliente_fizzy).denominazione.first(6), causale: "TD01", stato: "tutti")

      assert result["count"] >= 1
      assert(result["results"].all? { |d| d["causale"] == "TD01" })
    end
  end
end
