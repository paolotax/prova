require "test_helper"

class Api::V1::SearchJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :scuole, :clienti, :persone

  setup do
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  test "returns 401 without token" do
    get api_v1_search_index_path(q: "test")
    assert_response :unauthorized
  end

  test "returns envelope with empty query" do
    get api_v1_search_index_path(q: ""), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal 0, json["count"]
    assert_equal [], json["data"]
  end

  test "returns envelope with results" do
    scuola = scuole(:scuola_fizzy)
    get api_v1_search_index_path(q: scuola.denominazione.first(6)), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert json["count"] > 0
    assert_kind_of Array, json["data"]
    assert json["data"].first.key?("type")
    assert json["data"].first.key?("display")
  end

  test "returns actions" do
    scuola = scuole(:scuola_fizzy)
    get api_v1_search_index_path(q: scuola.denominazione.first(6)), headers: @headers

    json = JSON.parse(response.body)
    assert json.key?("actions")
    if json["data"].any?
      assert json["actions"].first["name"] == "crea_appunto"
    end
  end

  test "supports type filter" do
    get api_v1_search_index_path(q: "test", type: "scuola"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    json["data"].each { |r| assert_equal "Scuola", r["type"] }
  end

  test "supports limit param" do
    get api_v1_search_index_path(q: "test", limit: 1), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end
end
