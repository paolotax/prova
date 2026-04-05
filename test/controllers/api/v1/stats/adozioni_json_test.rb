require "test_helper"

class Api::V1::Stats::AdozioniJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  setup do
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  test "returns 401 without token" do
    get api_v1_stats_adozioni_path
    assert_response :unauthorized
  end

  test "returns envelope format" do
    get api_v1_stats_adozioni_path, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert json.key?("count")
    assert json.key?("data")
    assert json.key?("actions")
  end

  test "data contains query results" do
    get api_v1_stats_adozioni_path(provincia: "MI"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert json["data"].key?("results")
    assert json["data"].key?("totals")
  end
end
