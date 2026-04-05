require "test_helper"

class PersoneJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :persone, :scuole

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @persona = persone(:persona_fizzy)
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get persone_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  test "authenticates with bearer token" do
    get persone_path(account_id: @account.id), as: :json, headers: @headers
    assert_response :success
  end

  # Index

  test "index returns envelope JSON" do
    get persone_path(account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_kind_of Array, json["data"]
    assert json["count"].is_a?(Integer)
  end

  test "index supports search with terms param" do
    get persone_path(account_id: @account.id, terms: [@persona.cognome.first(4)]), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].any? { |p| p["id"] == @persona.id }
  end

  test "index supports limit param" do
    get persone_path(account_id: @account.id, limit: 1), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end

  test "index supports ruoli filter" do
    get persone_path(account_id: @account.id, ruoli: ["docente"]), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].all? { |p| p["ruolo"] == "docente" || p["ruolo"].nil? }
  end

  test "index supports stato_contatto con_email filter" do
    get persone_path(account_id: @account.id, stato_contatto: "con_email"), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    json["data"].each { |p| assert p["email"].present? }
  end

  test "index supports sorted_by recenti" do
    get persone_path(account_id: @account.id, sorted_by: "recenti"), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    dates = json["data"].map { |p| p["created_at"] }
    assert_equal dates, dates.sort.reverse
  end

  test "index includes actions" do
    get persone_path(account_id: @account.id), as: :json, headers: @headers

    json = JSON.parse(response.body)
    assert json.key?("actions")
  end

  # Show

  test "show returns persona JSON" do
    get persona_path(@persona, account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @persona.id, json["id"]
    assert_equal @persona.cognome, json["cognome"]
    assert_equal @persona.nome, json["nome"]
    assert json.key?("classi")
    assert json.key?("url")
    assert json.key?("scuola")
  end

  # Create

  test "create returns created persona" do
    assert_difference "Persona.count", 1 do
      post persone_path(account_id: @account.id), as: :json,
        params: { persona: { cognome: "Neri", nome: "Paolo", ruolo: "docente", email: "neri@test.it" } },
        headers: @headers
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Neri", json["cognome"]
    assert_equal "Paolo", json["nome"]
  end

  test "create returns errors for invalid data" do
    post persone_path(account_id: @account.id), as: :json,
      params: { persona: { cognome: "", nome: "" } },
      headers: @headers

    assert_response :unprocessable_entity
  end

  # Update

  test "update modifies persona" do
    patch persona_path(@persona, account_id: @account.id), as: :json,
      params: { persona: { email: "nuovo@email.it" } },
      headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "nuovo@email.it", json["email"]
  end

  # Destroy

  test "destroy removes persona" do
    persona = @account.persone.create!(cognome: "Da Eliminare")

    assert_difference "Persona.count", -1 do
      delete persona_path(persona, account_id: @account.id), as: :json, headers: @headers
    end

    assert_response :no_content
  end
end
