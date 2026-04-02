require "test_helper"

class Api::V1::Libri::ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :editori, :categorie

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
  end

  test "imports single libro via JSON POST" do
    assert_difference "Libro.count", 1 do
      post api_v1_libro_imports_path(libro_id: "import"),
        params: { isbn: "9788899900001", titolo: "Test Libro", prezzo: "12.50", editore: editori(:mondadori).id.to_s },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["imported"]
  end

  test "batch import with libri array" do
    assert_difference "Libro.count", 2 do
      post api_v1_libro_imports_path(libro_id: "import"),
        params: {
          libri: [
            { isbn: "9788899900002", titolo: "Libro Uno", prezzo: "10.00" },
            { isbn: "9788899900003", titolo: "Libro Due", prezzo: "15.00" }
          ]
        },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["imported"]
  end

  test "returns 401 without token" do
    post api_v1_libro_imports_path(libro_id: "import"),
      params: { isbn: "9788899900004", titolo: "No Auth" }
    assert_response :unauthorized
  end
end
