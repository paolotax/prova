require "test_helper"

class SearchControllerJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :scuole

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get search_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  # Show with query

  test "show returns search results as JSON" do
    get search_path(account_id: @account.id, q: "Leonardo"), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal "Leonardo", json["query"]
    assert json["count"].is_a?(Integer)
    assert_kind_of Array, json["data"]
  end

  test "show results include expected fields" do
    get search_path(account_id: @account.id, q: "Leonardo"), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    return if json["data"].empty?

    item = json["data"].first
    assert item.key?("id")
    assert item.key?("type")
    assert item.key?("appuntabile_value")
    assert item.key?("display")
  end

  # Blank query

  test "show returns 204 when query is blank" do
    get search_path(account_id: @account.id, q: ""), as: :json, headers: @headers
    assert_response :no_content
  end

  test "show returns 204 when query is too short" do
    get search_path(account_id: @account.id, q: "a"), as: :json, headers: @headers
    assert_response :no_content
  end

  test "show returns 204 when query param is missing" do
    get search_path(account_id: @account.id), as: :json, headers: @headers
    assert_response :no_content
  end
end
