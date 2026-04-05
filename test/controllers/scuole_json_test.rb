require "test_helper"

class ScuoleJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :scuole

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @scuola = scuole(:scuola_fizzy)
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get scuole_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  test "authenticates with bearer token" do
    get scuole_path(account_id: @account.id), as: :json, headers: @headers
    assert_response :success
  end

  # Index

  test "index returns envelope JSON" do
    get scuole_path(account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_kind_of Array, json["data"]
    assert json["count"].is_a?(Integer)
  end

  test "index supports search with terms param" do
    get scuole_path(account_id: @account.id, terms: [@scuola.denominazione.first(4)]), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].any? { |s| s["id"] == @scuola.id }
  end

  test "index supports limit param" do
    get scuole_path(account_id: @account.id, limit: 1), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end

  test "index includes actions" do
    get scuole_path(account_id: @account.id), as: :json, headers: @headers

    json = JSON.parse(response.body)
    assert json.key?("actions")
  end

  # Show

  test "show returns scuola JSON" do
    get scuola_path(@scuola, account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @scuola.id, json["id"]
    assert_equal @scuola.denominazione, json["denominazione"]
    assert json.key?("url")
    assert json.key?("codice_ministeriale")
  end

  # Update

  test "update modifies scuola" do
    patch scuola_path(@scuola, account_id: @account.id), as: :json,
      params: { scuola: { email: "nuova@scuola.it", telefono: "02 1234567" } },
      headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "nuova@scuola.it", json["email"]
    assert_equal "02 1234567", json["telefono"]
  end

  test "update returns errors for invalid data" do
    patch scuola_path(@scuola, account_id: @account.id), as: :json,
      params: { scuola: { denominazione: "" } },
      headers: @headers

    assert_response :unprocessable_entity
  end
end
