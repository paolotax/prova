require "test_helper"

class LibriControllerJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :libri, :editori, :categorie

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @libro = libri(:libro_fizzy)
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Create

  test "create returns created libro" do
    assert_difference "Libro.count", 1 do
      post libri_path(account_id: @account.id), as: :json,
        params: { libro: {
          titolo: "Nuovo Libro API",
          codice_isbn: "9788800099999",
          prezzo_in_cents: 2500,
          categoria_id: categorie(:ministeriali).id,
          editore_id: editori(:mondadori).id,
          classe: 3,
          disciplina: "Scienze"
        } },
        headers: @headers
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Nuovo Libro API", json["titolo"]
    assert_equal "9788800099999", json["codice_isbn"]
    assert_equal 2500, json["prezzo_cents"]
  end

  test "create returns errors for invalid data" do
    post libri_path(account_id: @account.id), as: :json,
      params: { libro: { titolo: "" } },
      headers: @headers

    assert_response :unprocessable_entity
  end

  # Update

  test "update modifies libro" do
    patch libro_path(@libro, account_id: @account.id), as: :json,
      params: { libro: { titolo: "Titolo Aggiornato" } },
      headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Titolo Aggiornato", json["titolo"]
  end

  test "update returns errors for invalid data" do
    patch libro_path(@libro, account_id: @account.id), as: :json,
      params: { libro: { titolo: "" } },
      headers: @headers

    assert_response :unprocessable_entity
  end

  # Destroy

  test "destroy removes libro" do
    libro = @account.libri.create!(
      user: @user,
      titolo: "Da eliminare",
      codice_isbn: "9788800088888",
      prezzo_in_cents: 1000,
      categoria: categorie(:ministeriali)
    )

    assert_difference "Libro.count", -1 do
      delete libro_path(libro, account_id: @account.id), as: :json, headers: @headers
    end

    assert_response :no_content
  end
end
