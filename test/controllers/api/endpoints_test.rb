require "test_helper"

class Api::EndpointsTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :scuole, :clienti, :persone

  setup do
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # === /api/me ===

  test "GET /api/me returns user info" do
    get api_me_path, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @membership.user.email, json["email"]
    assert_equal @membership.user.name, json["name"]
    assert_equal @account.name, json["account"]
    assert_equal @account.id, json["account_id"]
  end

  test "GET /api/me returns 401 without token" do
    get api_me_path
    assert_response :unauthorized
  end

  # === /api/search ===

  test "GET /api/search returns results" do
    scuola = scuole(:scuola_fizzy)
    get api_search_index_path(q: scuola.denominazione.first(6)), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert json["count"] > 0
    assert_kind_of Array, json["data"]
  end

  test "GET /api/search returns empty with short query" do
    get api_search_index_path(q: "x"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["count"]
    assert_equal [], json["data"]
  end

  test "GET /api/search returns 401 without token" do
    get api_search_index_path(q: "test")
    assert_response :unauthorized
  end

  # === /api/stats/adozioni ===

  test "GET /api/stats/adozioni returns stats" do
    get api_stats_adozioni_path, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert json.key?("count")
    assert json.key?("data")
    assert json.key?("actions")
  end

  test "GET /api/stats/adozioni returns 401 without token" do
    get api_stats_adozioni_path
    assert_response :unauthorized
  end
end
