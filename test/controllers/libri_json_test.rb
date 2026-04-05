require "test_helper"

class LibriJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :libri, :editori, :categorie

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @libro = libri(:libro_fizzy)
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get libri_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  # Index

  test "index returns envelope JSON" do
    get libri_path(account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_kind_of Array, json["data"]
    assert json["count"].is_a?(Integer)
  end

  test "index supports search with terms param" do
    get libri_path(account_id: @account.id, terms: [@libro.titolo.first(4)]), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].any? { |l| l["id"] == @libro.id }
  end

  test "index supports limit param" do
    get libri_path(account_id: @account.id, limit: 1), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end

  test "index includes actions" do
    get libri_path(account_id: @account.id), as: :json, headers: @headers

    json = JSON.parse(response.body)
    assert json.key?("actions")
  end

  test "index includes editore in data" do
    get libri_path(account_id: @account.id), as: :json, headers: @headers

    json = JSON.parse(response.body)
    libro_json = json["data"].find { |l| l["id"] == @libro.id }
    assert libro_json.key?("editore")
    assert libro_json.key?("prezzo_cents")
  end

  # Show

  test "show returns libro JSON" do
    get libro_path(@libro, account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @libro.id, json["id"]
    assert_equal @libro.titolo, json["titolo"]
    assert json.key?("url")
    assert json.key?("codice_isbn")
  end
end
