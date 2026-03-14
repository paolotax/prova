require "test_helper"

class Api::V1::AppuntiControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
  end

  test "creates draft appunto with valid token" do
    assert_difference "Appunto.count", 1 do
      post api_v1_appunti_path,
        params: { appunto: { nome: "Test API", content: "Contenuto" } },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "drafted", json["status"]
    assert_equal "Test API", json["nome"]
  end

  test "creates appunto with empty params" do
    assert_difference "Appunto.count", 1 do
      post api_v1_appunti_path,
        params: { appunto: {} },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end
    assert_response :created
  end

  test "sets user and account on created appunto" do
    post api_v1_appunti_path,
      params: { appunto: { nome: "Ownership test" } },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :created
    appunto = Appunto.find(JSON.parse(response.body)["appunto_id"])
    assert_equal @user, appunto.user
    assert_equal @account, appunto.account
  end

  test "updates last_used_at on token" do
    assert_nil @token.last_used_at

    post api_v1_appunti_path,
      params: { appunto: { nome: "Touch test" } },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :created
    @token.reload
    assert_not_nil @token.last_used_at
  end

  test "returns 401 without token" do
    post api_v1_appunti_path, params: { appunto: { nome: "No auth" } }
    assert_response :unauthorized
  end

  test "returns 401 with invalid token" do
    post api_v1_appunti_path,
      params: { appunto: { nome: "Bad" } },
      headers: { "Authorization" => "Bearer invalid_token_value" }
    assert_response :unauthorized
  end

  test "accepts token via api_key param" do
    assert_difference "Appunto.count", 1 do
      post api_v1_appunti_path,
        params: { api_key: @token.token, appunto: { nome: "Via param" } }
    end
    assert_response :created
  end
end
