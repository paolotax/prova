require "test_helper"

class ClientiJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :clienti

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @cliente = @account.clienti.first || @account.clienti.create!(denominazione: "Test Cliente")
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get clienti_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  test "authenticates with bearer token" do
    get clienti_path(account_id: @account.id), as: :json, headers: @headers
    assert_response :success
  end

  # Index

  test "index returns envelope JSON" do
    get clienti_path(account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_kind_of Array, json["data"]
    assert json["count"].is_a?(Integer)
  end

  test "index supports search with terms param" do
    get clienti_path(account_id: @account.id, terms: [@cliente.denominazione.first(4)]), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].any? { |c| c["id"] == @cliente.id }
  end

  test "index supports limit param" do
    get clienti_path(account_id: @account.id, limit: 1), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end

  # Show

  test "show returns cliente JSON" do
    get cliente_path(@cliente, account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @cliente.id, json["id"]
    assert_equal @cliente.denominazione, json["denominazione"]
  end

  # Create

  test "create returns created cliente" do
    assert_difference "Cliente.count", 1 do
      post clienti_path(account_id: @account.id), as: :json,
        params: { cliente: { denominazione: "Nuovo via API", comune: "Roma", provincia: "RM" } },
        headers: @headers
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Nuovo via API", json["denominazione"]
    assert_equal "Roma", json["comune"]
  end

  test "create returns errors for invalid data" do
    post clienti_path(account_id: @account.id), as: :json,
      params: { cliente: { denominazione: "" } },
      headers: @headers

    assert_response :unprocessable_entity
  end

  # Update

  test "update modifies cliente" do
    patch cliente_path(@cliente, account_id: @account.id), as: :json,
      params: { cliente: { email: "nuovo@email.it" } },
      headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "nuovo@email.it", json["email"]
  end

  # Delete

  test "destroy removes cliente" do
    cliente = @account.clienti.create!(denominazione: "Da eliminare")

    assert_difference "Cliente.count", -1 do
      delete cliente_path(cliente, account_id: @account.id), as: :json, headers: @headers
    end

    assert_response :no_content
  end
end
