require "test_helper"

class AppuntiJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :appunti

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @appunto = appunti(:appunto_fizzy)
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get appunti_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  # Index

  test "index returns envelope JSON" do
    get appunti_path(account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_kind_of Array, json["data"]
    assert json["count"].is_a?(Integer)
  end

  test "index supports limit param" do
    get appunti_path(account_id: @account.id, limit: 1), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end

  test "index includes actions" do
    get appunti_path(account_id: @account.id), as: :json, headers: @headers

    json = JSON.parse(response.body)
    assert json.key?("actions")
  end

  # Show

  test "show returns appunto JSON" do
    get appunto_path(@appunto, account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @appunto.id, json["id"]
    assert_equal @appunto.nome, json["nome"]
    assert json.key?("url")
  end
end
