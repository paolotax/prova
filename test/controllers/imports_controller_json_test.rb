# frozen_string_literal: true

require "test_helper"

class ImportsControllerJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :editori, :categorie, :scuole

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test JSON Import")
  end

  test "imports libri batch via JSON" do
    assert_difference "Libro.count", 2 do
      post "/#{@account.id}/imports.json",
        params: {
          type: "libri",
          items: [
            { isbn: "9788899900010", titolo: "Libro Uno JSON", prezzo: "10.00" },
            { isbn: "9788899900011", titolo: "Libro Due JSON", prezzo: "15.00" }
          ]
        },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["imported"]
    assert_equal 0, json["errors"].length
  end

  test "imports single libro via JSON" do
    assert_difference "Libro.count", 1 do
      post "/#{@account.id}/imports.json",
        params: {
          type: "libri",
          isbn: "9788899900012",
          titolo: "Libro Singolo JSON",
          prezzo: "12.50",
          editore: editori(:mondadori).id.to_s
        },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["imported"]
  end

  test "imports persone batch via JSON" do
    post "/#{@account.id}/imports.json",
      params: {
        type: "persone",
        items: [
          { cognome: "Rossi", nome: "Mario", scuola: "Leonardo" },
          { cognome: "Bianchi", nome: "Anna", scuola: "Leonardo" }
        ]
      },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["ok"]
    assert_includes json["summary"], "persone importate"
  end

  test "imports single persona via JSON" do
    post "/#{@account.id}/imports.json",
      params: {
        type: "persone",
        cognome: "Verdi",
        nome: "Luigi",
        scuola: "Leonardo"
      },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["ok"]
  end

  test "imports clienti batch via JSON" do
    assert_difference "Cliente.count", 2 do
      post "/#{@account.id}/imports.json",
        params: {
          type: "clienti",
          items: [
            { denominazione: "Libreria Test Uno", partita_iva: "11111111111" },
            { denominazione: "Libreria Test Due", partita_iva: "22222222222" }
          ]
        },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["imported"]
  end

  test "imports single cliente via JSON" do
    assert_difference "Cliente.count", 1 do
      post "/#{@account.id}/imports.json",
        params: {
          type: "clienti",
          denominazione: "Libreria Singola JSON",
          partita_iva: "98765432100"
        },
        headers: { "Authorization" => "Bearer #{@token.token}" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["imported"]
  end

  test "imports adozioni comunicate via JSON" do
    scuola = Scuola.create!(account: @account, denominazione: "PRIMARIA TEST JSON",
                            codice_ministeriale: "TESTJSON01X")
    classe = Classe.create!(account: @account, scuola: scuola, anno_corso: "3",
                            sezione: "B", combinazione: "", stato: "attiva",
                            anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: classe, codice_isbn: "9788809917583",
                     anno_scolastico: "202627", codicescuola: "TESTJSON01X", anno_corso: "3")

    post "/#{@account.id}/imports.json",
      params: {
        type: "adozioni_comunicate",
        anno_scolastico: "202627",
        editore: "GIUNTI SCUOLA",
        items: [
          { codicescuola: "TESTJSON01X", ean: "978-88-0991-7583", classe: "3", sezioni: "B", alunni: 25 }
        ]
      },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["ok"]
    assert_equal 1, json["importate"]
    assert_equal 1, json["matched"]
    assert_equal 25, classe.reload.numero_alunni
  end

  test "returns error when anno_scolastico missing for adozioni comunicate" do
    post "/#{@account.id}/imports.json",
      params: { type: "adozioni_comunicate", items: [] },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["ok"]
    assert_includes json["error"], "anno_scolastico"
  end

  test "returns error for invalid import type" do
    post "/#{@account.id}/imports.json",
      params: { type: "invalid_type", items: [{ foo: "bar" }] },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["ok"]
    assert_includes json["error"], "Tipo non valido"
  end

  test "returns 401 without token for JSON" do
    post "/#{@account.id}/imports.json",
      params: { type: "libri", items: [{ isbn: "9788899900099", titolo: "No Auth" }] }

    assert_response :unauthorized
  end
end
