require "test_helper"

class Api::V1::Clienti::ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
  end

  test "imports single cliente" do
    assert_difference "Cliente.count", 1 do
      post api_v1_cliente_imports_path(cliente_id: "import"),
        params: { denominazione: "Libreria Test", partita_iva: "55555555501" },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["imported"]
  end

  test "batch import with clienti array" do
    assert_difference "Cliente.count", 2 do
      post api_v1_cliente_imports_path(cliente_id: "import"),
        params: {
          clienti: [
            { denominazione: "Libreria Alfa", partita_iva: "55555555502" },
            { denominazione: "Libreria Beta", partita_iva: "55555555503" }
          ]
        },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["imported"]
  end

  test "returns 401 without token" do
    post api_v1_cliente_imports_path(cliente_id: "import"),
      params: { denominazione: "No Auth" }
    assert_response :unauthorized
  end
end
