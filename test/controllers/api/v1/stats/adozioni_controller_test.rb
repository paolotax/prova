require "test_helper"

class Api::V1::Stats::AdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  setup do
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test Stats API")

    # Create test data inline
    conn = ActiveRecord::Base.connection
    conn.execute <<~SQL
      INSERT INTO tipi_scuole (tipo, grado, created_at, updated_at)
      VALUES ('SCUOLA PRIMARIA CTRL TEST', 'E', NOW(), NOW())
      ON CONFLICT DO NOTHING
    SQL
    conn.execute <<~SQL
      INSERT INTO import_scuole ("CODICESCUOLA", "DENOMINAZIONESCUOLA", "PROVINCIA", "REGIONE", "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", created_at, updated_at)
      VALUES ('TOEE99999Z', 'TEST ELEMENTARE', 'TO', 'PIEMONTE', 'SCUOLA PRIMARIA CTRL TEST', NOW(), NOW())
    SQL
    conn.execute <<~SQL
      INSERT INTO import_adozioni ("CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "DISCIPLINA", "CODICEISBN", "AUTORI", "TITOLO", "EDITORE", "PREZZO", "DAACQUIST", "NUOVAADOZ", "CONSIGLIATO", "COMBINAZIONE", "TIPOGRADOSCUOLA", created_at, updated_at)
      VALUES ('TOEE99999Z', '3', 'A', 'MATEMATICA', '9789999000001', 'Test Author', 'TEST BOOK', 'TESTPUB', '10,00', 'Si', 'Si', 'No', '40 ORE', 'EE', NOW(), NOW())
    SQL
  end

  teardown do
    conn = ActiveRecord::Base.connection
    conn.execute "DELETE FROM import_adozioni WHERE \"CODICESCUOLA\" = 'TOEE99999Z'"
    conn.execute "DELETE FROM import_scuole WHERE \"CODICESCUOLA\" = 'TOEE99999Z'"
    conn.execute "DELETE FROM tipi_scuole WHERE tipo = 'SCUOLA PRIMARIA CTRL TEST'"
  end

  test "returns stats grouped by editore" do
    get api_v1_stats_adozioni_path,
      params: { group_by: "editore", provincia: "TO" },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal({ "provincia" => "TO" }, json["filters_applied"])
    assert_equal ["editore"], json["group_by"]
    assert json["totals"]["classi_count"] > 0
    assert json["results"].is_a?(Array)
    assert json["results"].first.key?("editore")
    assert json["results"].first.key?("classi_count")
    assert json["results"].first.key?("percentuale")
    assert json["results"].first.key?("copie_stimate")
    assert json["results"].first.key?("importo_cents")
  end

  test "accepts coefficiente parameter" do
    get api_v1_stats_adozioni_path,
      params: { group_by: "editore", coefficiente: 25 },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 25, json["coefficiente"]
  end

  test "returns 401 without token" do
    get api_v1_stats_adozioni_path, params: { group_by: "editore" }
    assert_response :unauthorized
  end

  test "multi group_by comma-separated" do
    get api_v1_stats_adozioni_path,
      params: { group_by: "editore,disciplina" },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal %w[editore disciplina], json["group_by"]
  end
end
