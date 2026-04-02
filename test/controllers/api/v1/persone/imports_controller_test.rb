require "test_helper"

class Api::V1::Persone::ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :scuole

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
  end

  test "imports single persona" do
    post api_v1_persona_imports_path(persona_id: "import"),
      params: { cognome: "Rossi", nome: "Mario", scuola: "Leonardo" },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["ok"]
  end

  test "batch import with persone array" do
    post api_v1_persona_imports_path(persona_id: "import"),
      params: {
        persone: [
          { cognome: "Bianchi", nome: "Anna", scuola: "Leonardo" },
          { cognome: "Verdi", nome: "Luigi", scuola: "Leonardo" }
        ]
      },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["ok"]
  end

  test "returns 401 without token" do
    post api_v1_persona_imports_path(persona_id: "import"),
      params: { cognome: "Rossi", scuola: "Leonardo" }
    assert_response :unauthorized
  end
end
