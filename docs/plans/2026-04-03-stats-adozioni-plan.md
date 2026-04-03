# Stats Adozioni API — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Flexible API endpoint for elementary school adoption statistics with dynamic grouping, consumed by Scagnozz CLI/MCP.

**Architecture:** Single `GET /api/v1/stats/adozioni` endpoint backed by `Stats::AdozioniQuery` model that builds dynamic SQL on `import_adozioni` + `import_scuole` + `tipi_scuole`. Any combination of filters and group_by dimensions. Scagnozz CLI adds MCP tool + CLI command.

**Tech Stack:** Rails API controller, raw SQL via `ActiveRecord::Base.connection`, Minitest integration tests, Go MCP tool.

**Design doc:** `docs/plans/2026-04-03-stats-adozioni-api-design.md`

---

### Task 1: Stats::AdozioniQuery — failing test

**Files:**
- Create: `test/models/stats/adozioni_query_test.rb`

Tests create import data inline (no fixtures exist for import_scuole/import_adozioni/tipi_scuole).

**Step 1: Write the failing test**

```ruby
require "test_helper"

class Stats::AdozioniQueryTest < ActiveSupport::TestCase
  setup do
    # Create tipo_scuola for elementary
    TipoScuola.find_or_create_by!(tipo: "SCUOLA PRIMARIA", grado: "E")

    # Create two schools in different provinces
    @scuola_to = ImportScuola.create!(
      CODICESCUOLA: "TOEE12345A",
      DENOMINAZIONESCUOLA: "Scuola Elementare Torino",
      PROVINCIA: "TO",
      REGIONE: "PIEMONTE",
      DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: "SCUOLA PRIMARIA"
    )
    @scuola_mi = ImportScuola.create!(
      CODICESCUOLA: "MIEE67890B",
      DENOMINAZIONESCUOLA: "Scuola Elementare Milano",
      PROVINCIA: "MI",
      REGIONE: "LOMBARDIA",
      DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: "SCUOLA PRIMARIA"
    )

    # Adozioni in Torino: 2 classi matematica Pearson, 1 classe matematica Mondadori
    ImportAdozione.create!(
      CODICESCUOLA: "TOEE12345A", ANNOCORSO: "3", SEZIONEANNO: "A",
      COMBINAZIONE: "40 ORE SETTIMANALI", TIPOGRADOSCUOLA: "SCUOLA PRIMARIA",
      TITOLO: "PEPPER 1 STAMPATO", CODICEISBN: "9788891000001",
      AUTORI: "Smith J.", EDITORE: "PEARSON", DISCIPLINA: "MATEMATICA",
      PREZZO: "12,50", DAACQUIST: "Si", NUOVAADOZ: "Si", CONSIGLIATO: "No"
    )
    ImportAdozione.create!(
      CODICESCUOLA: "TOEE12345A", ANNOCORSO: "3", SEZIONEANNO: "B",
      COMBINAZIONE: "40 ORE SETTIMANALI", TIPOGRADOSCUOLA: "SCUOLA PRIMARIA",
      TITOLO: "PEPPER 1 4CARATTERI", CODICEISBN: "9788891000002",
      AUTORI: "Smith J.", EDITORE: "PEARSON", DISCIPLINA: "MATEMATICA",
      PREZZO: "12,50", DAACQUIST: "Si", NUOVAADOZ: "Si", CONSIGLIATO: "No"
    )
    ImportAdozione.create!(
      CODICESCUOLA: "TOEE12345A", ANNOCORSO: "3", SEZIONEANNO: "C",
      COMBINAZIONE: "27 ORE SETTIMANALI", TIPOGRADOSCUOLA: "SCUOLA PRIMARIA",
      TITOLO: "MONDO MATEMATICA 3", CODICEISBN: "9788891000003",
      AUTORI: "Rossi A.", EDITORE: "MONDADORI", DISCIPLINA: "MATEMATICA",
      PREZZO: "15,00", DAACQUIST: "Si", NUOVAADOZ: "No", CONSIGLIATO: "No"
    )

    # Adozione in Milano: 1 classe italiano Pearson
    ImportAdozione.create!(
      CODICESCUOLA: "MIEE67890B", ANNOCORSO: "3", SEZIONEANNO: "A",
      COMBINAZIONE: "40 ORE SETTIMANALI", TIPOGRADOSCUOLA: "SCUOLA PRIMARIA",
      TITOLO: "LEGGERE E SCRIVERE 3", CODICEISBN: "9788891000004",
      AUTORI: "Bianchi L.", EDITORE: "PEARSON", DISCIPLINA: "ITALIANO",
      PREZZO: "10,00", DAACQUIST: "Si", NUOVAADOZ: "Si", CONSIGLIATO: "No"
    )

    # Adozione non da acquistare (deve essere esclusa)
    ImportAdozione.create!(
      CODICESCUOLA: "TOEE12345A", ANNOCORSO: "3", SEZIONEANNO: "A",
      COMBINAZIONE: "40 ORE SETTIMANALI", TIPOGRADOSCUOLA: "SCUOLA PRIMARIA",
      TITOLO: "ATLAS CONSIGLIATO", CODICEISBN: "9788891000005",
      AUTORI: "Verdi G.", EDITORE: "ATLAS", DISCIPLINA: "SCIENZE",
      PREZZO: "8,00", DAACQUIST: "No", NUOVAADOZ: "No", CONSIGLIATO: "Si"
    )
  end

  teardown do
    ImportAdozione.delete_all
    ImportScuola.delete_all
    TipoScuola.where(tipo: "SCUOLA PRIMARIA").delete_all
  end

  test "group by editore returns classi_count, percentuale, copie_stimate, importo" do
    result = Stats::AdozioniQuery.new(
      filters: { provincia: "TO" },
      group_by: %w[editore],
      coefficiente: 18
    ).call

    assert_equal({ "provincia" => "TO" }, result[:filters_applied])
    assert_equal %w[editore], result[:group_by]
    assert_equal 18, result[:coefficiente]

    # Totals: 3 classi in TO (A, B, C), 1 scuola
    assert_equal 3, result[:totals][:classi_count]
    assert_equal 1, result[:totals][:scuole_count]
    assert_equal 54, result[:totals][:copie_stimate] # 3 * 18

    # Results ordered by classi_count desc
    assert_equal 2, result[:results].size
    pearson = result[:results].first
    assert_equal "PEARSON", pearson[:editore]
    assert_equal 2, pearson[:classi_count]
    assert_equal 36, pearson[:copie_stimate] # 2 * 18
    assert_in_delta 66.67, pearson[:percentuale], 0.01 # 2/3 * 100
  end

  test "group by disciplina with editore filter" do
    result = Stats::AdozioniQuery.new(
      filters: { editore: "PEARSON" },
      group_by: %w[disciplina]
    ).call

    # Pearson has 2 classi matematica (TO) + 1 classe italiano (MI)
    assert_equal 3, result[:totals][:classi_count]
    assert_equal 2, result[:results].size

    matematica = result[:results].find { |r| r[:disciplina] == "MATEMATICA" }
    assert_equal 2, matematica[:classi_count]
  end

  test "group by provincia returns all provinces" do
    result = Stats::AdozioniQuery.new(
      filters: {},
      group_by: %w[provincia]
    ).call

    assert_equal 4, result[:totals][:classi_count] # 3 TO + 1 MI
    assert_equal 2, result[:results].size
    assert_equal "TO", result[:results].first[:provincia] # 3 classi > 1
  end

  test "titolo filter uses ILIKE partial match" do
    result = Stats::AdozioniQuery.new(
      filters: { titolo: "PEPPER 1" },
      group_by: %w[provincia]
    ).call

    # Only PEPPER 1 STAMPATO and PEPPER 1 4CARATTERI match
    assert_equal 2, result[:totals][:classi_count]
    assert_equal 1, result[:results].size
    assert_equal "TO", result[:results].first[:provincia]
  end

  test "group by titolo includes isbn, autori, prezzo" do
    result = Stats::AdozioniQuery.new(
      filters: { provincia: "TO", disciplina: "MATEMATICA" },
      group_by: %w[titolo]
    ).call

    assert result[:results].all? { |r| r.key?(:isbn) }
    assert result[:results].all? { |r| r.key?(:autori) }
    assert result[:results].all? { |r| r.key?(:prezzo) }
  end

  test "group by scuola includes denominazione and provincia" do
    result = Stats::AdozioniQuery.new(
      filters: {},
      group_by: %w[scuola]
    ).call

    assert result[:results].all? { |r| r.key?(:denominazione) }
    assert result[:results].all? { |r| r.key?(:provincia) }
  end

  test "excludes non-da-acquistare adozioni" do
    result = Stats::AdozioniQuery.new(
      filters: { provincia: "TO" },
      group_by: %w[editore]
    ).call

    editori = result[:results].map { |r| r[:editore] }
    assert_not_includes editori, "ATLAS"
  end

  test "coefficiente changes copie_stimate and importo" do
    result = Stats::AdozioniQuery.new(
      filters: { provincia: "TO" },
      group_by: %w[editore],
      coefficiente: 25
    ).call

    assert_equal 75, result[:totals][:copie_stimate] # 3 * 25
    pearson = result[:results].find { |r| r[:editore] == "PEARSON" }
    assert_equal 50, pearson[:copie_stimate] # 2 * 25
  end

  test "limit restricts results" do
    result = Stats::AdozioniQuery.new(
      filters: { provincia: "TO" },
      group_by: %w[editore],
      limit: 1
    ).call

    assert_equal 1, result[:results].size
  end

  test "multi-dimension group_by works" do
    result = Stats::AdozioniQuery.new(
      filters: {},
      group_by: %w[editore classe]
    ).call

    # All are classe 3, so groups are: PEARSON/3, MONDADORI/3
    assert result[:results].all? { |r| r.key?(:editore) && r.key?(:classe) }
  end

  test "returns empty results for no matches" do
    result = Stats::AdozioniQuery.new(
      filters: { provincia: "RM" },
      group_by: %w[editore]
    ).call

    assert_equal 0, result[:totals][:classi_count]
    assert_empty result[:results]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/stats/adozioni_query_test.rb`
Expected: FAIL — `NameError: uninitialized constant Stats::AdozioniQuery`

**Step 3: Commit**

```bash
git add test/models/stats/adozioni_query_test.rb
git commit -m "test: add Stats::AdozioniQuery tests (red)"
```

---

### Task 2: Stats::AdozioniQuery — implementation

**Files:**
- Create: `app/models/stats/adozioni_query.rb`

**Step 1: Implement the model**

```ruby
module Stats
  class AdozioniQuery
    DIMENSIONS = {
      "editore"    => 'ia."EDITORE"',
      "disciplina" => 'ia."DISCIPLINA"',
      "classe"     => 'ia."ANNOCORSO"',
      "provincia"  => 'isc."PROVINCIA"',
      "titolo"     => 'ia."TITOLO"',
      "scuola"     => 'isc."CODICESCUOLA"'
    }.freeze

    EXTRA_COLUMNS = {
      "titolo" => [
        'ia."CODICEISBN" as isbn',
        'ia."AUTORI" as autori',
        'ia."PREZZO" as prezzo'
      ],
      "scuola" => [
        'isc."DENOMINAZIONESCUOLA" as denominazione',
        'isc."PROVINCIA" as provincia'
      ]
    }.freeze

    FILTERS = {
      "provincia"    => 'isc."PROVINCIA" = ?',
      "regione"      => 'isc."REGIONE" = ?',
      "classe"       => 'ia."ANNOCORSO" = ?',
      "editore"      => 'ia."EDITORE" = ?',
      "disciplina"   => 'ia."DISCIPLINA" = ?',
      "titolo"       => 'ia."TITOLO" ILIKE ?',
      "isbn"         => 'ia."CODICEISBN" = ?',
      "combinazione" => 'ia."COMBINAZIONE" = ?'
    }.freeze

    ORDER_COLUMNS = %w[classi_count scuole_count adozioni_count copie_stimate importo percentuale].freeze

    def initialize(filters:, group_by:, coefficiente: 18, order_by: :classi_count, limit: 50)
      @filters = filters.to_h.stringify_keys.select { |_, v| v.present? }
      @group_by = Array(group_by).select { |d| DIMENSIONS.key?(d) }
      @coefficiente = coefficiente
      @order_by = ORDER_COLUMNS.include?(order_by.to_s) ? order_by.to_s : "classi_count"
      @limit = [limit, 500].min
    end

    def call
      {
        filters_applied: @filters,
        group_by: @group_by,
        coefficiente: @coefficiente,
        totals: totals,
        results: results
      }
    end

    private

    def base_from
      <<~SQL
        FROM import_adozioni ia
        INNER JOIN import_scuole isc ON isc."CODICESCUOLA" = ia."CODICESCUOLA"
        INNER JOIN tipi_scuole ts ON ts.tipo = isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
      SQL
    end

    def base_where
      conditions = ['ts.grado = ?', 'ia."DAACQUIST" = ?']
      binds = ["E", "Si"]

      @filters.each do |key, value|
        next unless FILTERS.key?(key)
        if key == "titolo"
          conditions << FILTERS[key]
          binds << "%#{value}%"
        else
          conditions << FILTERS[key]
          binds << value
        end
      end

      [conditions.join(" AND "), binds]
    end

    def group_columns
      @group_by.map { |d| DIMENSIONS[d] }
    end

    def extra_columns
      @group_by.flat_map { |d| EXTRA_COLUMNS.fetch(d, []) }
    end

    def select_aggregates
      <<~SQL
        COUNT(DISTINCT (ia."CODICESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO")) as classi_count,
        COUNT(DISTINCT ia."CODICESCUOLA") as scuole_count,
        COUNT(*) as adozioni_count
      SQL
    end

    def totals
      conditions, binds = base_where
      sql = "SELECT #{select_aggregates} #{base_from} WHERE #{conditions}"
      sanitized = ActiveRecord::Base.sanitize_sql_array([sql, *binds])
      row = ActiveRecord::Base.connection.select_one(sanitized)

      return { classi_count: 0, scuole_count: 0, copie_stimate: 0, importo_cents: 0 } if row.nil? || row["classi_count"].to_i == 0

      classi = row["classi_count"].to_i
      {
        classi_count: classi,
        scuole_count: row["scuole_count"].to_i,
        copie_stimate: classi * @coefficiente,
        importo_cents: compute_importo_totals(conditions, binds, classi)
      }
    end

    def compute_importo_totals(conditions, binds, classi)
      sql = <<~SQL
        SELECT SUM(CAST(REPLACE(ia."PREZZO", ',', '.') AS numeric)) as prezzo_sum,
               COUNT(*) as cnt
        #{base_from}
        WHERE #{conditions}
      SQL
      sanitized = ActiveRecord::Base.sanitize_sql_array([sql, *binds])
      row = ActiveRecord::Base.connection.select_one(sanitized)
      return 0 unless row && row["cnt"].to_i > 0

      prezzo_avg = row["prezzo_sum"].to_f / row["cnt"].to_i
      (prezzo_avg * classi * @coefficiente * 100).round
    end

    def results
      return [] if @group_by.empty?

      total_classi = totals[:classi_count]
      return [] if total_classi == 0

      conditions, binds = base_where
      gc = group_columns
      ec = extra_columns

      select_parts = gc + ec + [select_aggregates]
      select_parts << <<~SQL
        SUM(CAST(REPLACE(ia."PREZZO", ',', '.') AS numeric)) as prezzo_sum
      SQL

      sql = <<~SQL
        SELECT #{select_parts.join(", ")}
        #{base_from}
        WHERE #{conditions}
        GROUP BY #{gc.join(", ")}
        ORDER BY #{@order_by == "percentuale" ? "classi_count" : @order_by} DESC
        LIMIT #{@limit}
      SQL

      sanitized = ActiveRecord::Base.sanitize_sql_array([sql, *binds])
      rows = ActiveRecord::Base.connection.select_all(sanitized)

      rows.map do |row|
        entry = {}
        @group_by.each { |d| entry[d.to_sym] = row[column_alias(d)] }
        EXTRA_COLUMNS.each do |dim, cols|
          next unless @group_by.include?(dim)
          cols.each do |col|
            alias_name = col.split(" as ").last.strip
            entry[alias_name.to_sym] = row[alias_name]
          end
        end

        classi = row["classi_count"].to_i
        entry[:classi_count] = classi
        entry[:scuole_count] = row["scuole_count"].to_i
        entry[:adozioni_count] = row["adozioni_count"].to_i
        entry[:copie_stimate] = classi * @coefficiente

        prezzo_avg = row["adozioni_count"].to_i > 0 ? row["prezzo_sum"].to_f / row["adozioni_count"].to_i : 0
        entry[:importo_cents] = (prezzo_avg * classi * @coefficiente * 100).round

        entry[:percentuale] = (classi.to_f / total_classi * 100).round(2)
        entry
      end
    end

    def column_alias(dimension)
      case dimension
      when "editore"    then "EDITORE"
      when "disciplina" then "DISCIPLINA"
      when "classe"     then "ANNOCORSO"
      when "provincia"  then "PROVINCIA"
      when "titolo"     then "TITOLO"
      when "scuola"     then "CODICESCUOLA"
      end
    end
  end
end
```

**Step 2: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/models/stats/adozioni_query_test.rb`
Expected: all PASS

**Step 3: Commit**

```bash
git add app/models/stats/adozioni_query.rb
git commit -m "feat: Stats::AdozioniQuery — flexible adoption stats with dynamic grouping"
```

---

### Task 3: API controller — failing test

**Files:**
- Create: `test/controllers/api/v1/stats/adozioni_controller_test.rb`

**Step 1: Write the failing test**

```ruby
require "test_helper"

class Api::V1::Stats::AdozioniControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships

  setup do
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test Stats API")

    TipoScuola.find_or_create_by!(tipo: "SCUOLA PRIMARIA", grado: "E")
    ImportScuola.create!(
      CODICESCUOLA: "TOEE99999Z",
      DENOMINAZIONESCUOLA: "Test Elementare",
      PROVINCIA: "TO",
      REGIONE: "PIEMONTE",
      DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: "SCUOLA PRIMARIA"
    )
    ImportAdozione.create!(
      CODICESCUOLA: "TOEE99999Z", ANNOCORSO: "3", SEZIONEANNO: "A",
      COMBINAZIONE: "40 ORE SETTIMANALI", TIPOGRADOSCUOLA: "SCUOLA PRIMARIA",
      TITOLO: "TEST BOOK", CODICEISBN: "9789999000001",
      AUTORI: "Test Author", EDITORE: "TESTPUB", DISCIPLINA: "MATEMATICA",
      PREZZO: "10,00", DAACQUIST: "Si", NUOVAADOZ: "Si", CONSIGLIATO: "No"
    )
  end

  teardown do
    ImportAdozione.delete_all
    ImportScuola.where(CODICESCUOLA: "TOEE99999Z").delete_all
    TipoScuola.where(tipo: "SCUOLA PRIMARIA").delete_all
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
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/controllers/api/v1/stats/adozioni_controller_test.rb`
Expected: FAIL — routing error or controller not found

**Step 3: Commit**

```bash
git add test/controllers/api/v1/stats/adozioni_controller_test.rb
git commit -m "test: add Stats::AdozioniController integration tests (red)"
```

---

### Task 4: API controller + route — implementation

**Files:**
- Create: `app/controllers/api/v1/stats/adozioni_controller.rb`
- Modify: `config/routes.rb` (add route in api/v1 namespace)

**Step 1: Create the controller**

```ruby
module Api
  module V1
    module Stats
      class AdozioniController < ActionController::API
        include Api::TokenAuthenticatable

        before_action :authenticate_api!

        def index
          query = ::Stats::AdozioniQuery.new(
            filters: filter_params,
            group_by: params[:group_by]&.split(","),
            coefficiente: params.fetch(:coefficiente, 18).to_i,
            order_by: params.fetch(:order_by, :classi_count).to_sym,
            limit: params.fetch(:limit, 50).to_i
          )

          render json: query.call
        end

        private

        def filter_params
          params.permit(:provincia, :regione, :classe, :editore,
                        :disciplina, :titolo, :isbn, :combinazione)
        end
      end
    end
  end
end
```

**Step 2: Add the route**

In `config/routes.rb`, inside the `namespace :api` → `namespace :v1` block, add:

```ruby
namespace :stats do
  get :adozioni, to: "adozioni#index"
end
```

Add it right after `resources :search, only: [:index]` (around line 537).

**Step 3: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/controllers/api/v1/stats/adozioni_controller_test.rb`
Expected: all PASS

**Step 4: Run model tests too to make sure nothing broke**

Run: `docker exec prova-app-1 bin/rails test test/models/stats/adozioni_query_test.rb test/controllers/api/v1/stats/adozioni_controller_test.rb`
Expected: all PASS

**Step 5: Commit**

```bash
git add app/controllers/api/v1/stats/adozioni_controller.rb config/routes.rb
git commit -m "feat: API endpoint GET /api/v1/stats/adozioni with flexible grouping"
```

---

### Task 5: Scagnozz CLI — MCP tool + CLI command

**Files:**
- Modify: `/home/paolotax/rails_2023/scagnozz-cli/internal/mcp/tools.go` (add registerStatsAdozioni)
- Create: `/home/paolotax/rails_2023/scagnozz-cli/internal/commands/stats.go` (CLI command)

**Step 1: Add MCP tool in tools.go**

Add to `registerTools()`:
```go
registerStatsAdozioni(server, apiClient)
```

Add the input struct and registration function:

```go
type StatsAdozioniInput struct {
	GroupBy      string `json:"group_by" jsonschema:"Dimensioni di aggregamento (virgola-separati): editore, disciplina, classe, provincia, titolo, scuola"`
	Provincia    string `json:"provincia,omitempty" jsonschema:"Codice provincia (es. TO, MI, RM)"`
	Regione      string `json:"regione,omitempty" jsonschema:"Nome regione (es. PIEMONTE)"`
	Classe       string `json:"classe,omitempty" jsonschema:"Anno corso: 1, 2, 3, 4, 5"`
	Editore      string `json:"editore,omitempty" jsonschema:"Nome editore (es. PEARSON)"`
	Disciplina   string `json:"disciplina,omitempty" jsonschema:"Materia (es. MATEMATICA, ITALIANO, LINGUA INGLESE)"`
	Titolo       string `json:"titolo,omitempty" jsonschema:"Ricerca parziale nel titolo (es. PEPPER 1 raggruppa tutte le varianti)"`
	ISBN         string `json:"isbn,omitempty" jsonschema:"Codice ISBN"`
	Coefficiente int    `json:"coefficiente,omitempty" jsonschema:"Alunni per classe per stima copie (default 18)"`
	OrderBy      string `json:"order_by,omitempty" jsonschema:"Ordinamento: classi_count (default), adozioni_count, percentuale, importo"`
	Limit        int    `json:"limit,omitempty" jsonschema:"Max risultati (default 50)"`
}

func registerStatsAdozioni(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name: "stats_adozioni",
		Description: "Statistiche adozioni elementari con aggregamenti flessibili. " +
			"Filtra per provincia, classe, editore, disciplina, titolo (parziale), isbn. " +
			"Aggrega con group_by: editore, disciplina, classe, provincia, titolo, scuola. " +
			"Restituisce conteggio classi, scuole, copie stimate, importo e percentuale sul totale filtrato.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args StatsAdozioniInput) (*gomcp.CallToolResult, any, error) {
		params := url.Values{}
		if args.GroupBy != "" {
			params.Set("group_by", args.GroupBy)
		}
		if args.Provincia != "" {
			params.Set("provincia", args.Provincia)
		}
		if args.Regione != "" {
			params.Set("regione", args.Regione)
		}
		if args.Classe != "" {
			params.Set("classe", args.Classe)
		}
		if args.Editore != "" {
			params.Set("editore", args.Editore)
		}
		if args.Disciplina != "" {
			params.Set("disciplina", args.Disciplina)
		}
		if args.Titolo != "" {
			params.Set("titolo", args.Titolo)
		}
		if args.ISBN != "" {
			params.Set("isbn", args.ISBN)
		}
		if args.Coefficiente > 0 {
			params.Set("coefficiente", fmt.Sprintf("%d", args.Coefficiente))
		}
		if args.OrderBy != "" {
			params.Set("order_by", args.OrderBy)
		}
		if args.Limit > 0 {
			params.Set("limit", fmt.Sprintf("%d", args.Limit))
		}

		data, err := apiClient.Get("/api/v1/stats/adozioni", params)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}
```

**Step 2: Create CLI command**

Create `/home/paolotax/rails_2023/scagnozz-cli/internal/commands/stats.go`:

```go
package commands

import (
	"encoding/json"
	"fmt"
	"net/url"

	"github.com/paolotax/scagnozz-cli/internal/render"
	"github.com/spf13/cobra"
)

var (
	statsGroupBy      string
	statsProvincia    string
	statsRegione      string
	statsClasse       string
	statsEditore      string
	statsDisciplina   string
	statsTitolo       string
	statsISBN         string
	statsCoefficienti int
	statsOrderBy      string
	statsLimit        int
)

var statsCmd = &cobra.Command{
	Use:   "stats",
	Short: "Statistiche adozioni elementari",
}

var statsAdozioniCmd = &cobra.Command{
	Use:   "adozioni",
	Short: "Statistiche adozioni con aggregamenti flessibili",
	Long: `Statistiche adozioni elementari con aggregamenti flessibili.

Esempi:
  scagnozz stats adozioni --group-by editore --provincia TO
  scagnozz stats adozioni --group-by editore,disciplina --classe 3
  scagnozz stats adozioni --group-by provincia --titolo "PEPPER 1"
  scagnozz stats adozioni --group-by scuola --provincia TO --editore PEARSON`,
	RunE: func(cmd *cobra.Command, args []string) error {
		params := url.Values{}
		if statsGroupBy != "" {
			params.Set("group_by", statsGroupBy)
		}
		if statsProvincia != "" {
			params.Set("provincia", statsProvincia)
		}
		if statsRegione != "" {
			params.Set("regione", statsRegione)
		}
		if statsClasse != "" {
			params.Set("classe", statsClasse)
		}
		if statsEditore != "" {
			params.Set("editore", statsEditore)
		}
		if statsDisciplina != "" {
			params.Set("disciplina", statsDisciplina)
		}
		if statsTitolo != "" {
			params.Set("titolo", statsTitolo)
		}
		if statsISBN != "" {
			params.Set("isbn", statsISBN)
		}
		if statsCoefficienti > 0 {
			params.Set("coefficiente", fmt.Sprintf("%d", statsCoefficienti))
		}
		if statsOrderBy != "" {
			params.Set("order_by", statsOrderBy)
		}
		if statsLimit > 0 {
			params.Set("limit", fmt.Sprintf("%d", statsLimit))
		}

		data, err := apiClient.Get("/api/v1/stats/adozioni", params)
		if err != nil {
			render.Error(err.Error())
			return err
		}

		var resp map[string]any
		if err := json.Unmarshal(data, &resp); err != nil {
			render.Error(err.Error())
			return err
		}

		results, _ := resp["results"].([]any)
		summary := fmt.Sprintf("%d risultati", len(results))
		if filters, ok := resp["filters_applied"].(map[string]any); ok && len(filters) > 0 {
			for k, v := range filters {
				summary += fmt.Sprintf(", %s=%v", k, v)
			}
		}

		render.Success(resp, summary)
		return nil
	},
}

func init() {
	statsAdozioniCmd.Flags().StringVar(&statsGroupBy, "group-by", "", "Dimensioni: editore,disciplina,classe,provincia,titolo,scuola")
	statsAdozioniCmd.Flags().StringVar(&statsProvincia, "provincia", "", "Codice provincia (TO, MI, ...)")
	statsAdozioniCmd.Flags().StringVar(&statsRegione, "regione", "", "Nome regione")
	statsAdozioniCmd.Flags().StringVar(&statsClasse, "classe", "", "Anno corso (1-5)")
	statsAdozioniCmd.Flags().StringVar(&statsEditore, "editore", "", "Nome editore")
	statsAdozioniCmd.Flags().StringVar(&statsDisciplina, "disciplina", "", "Materia")
	statsAdozioniCmd.Flags().StringVar(&statsTitolo, "titolo", "", "Ricerca parziale nel titolo")
	statsAdozioniCmd.Flags().StringVar(&statsISBN, "isbn", "", "Codice ISBN")
	statsAdozioniCmd.Flags().IntVar(&statsCoefficienti, "coefficiente", 0, "Alunni per classe (default 18)")
	statsAdozioniCmd.Flags().StringVar(&statsOrderBy, "order-by", "", "Ordinamento: classi_count, adozioni_count, percentuale, importo")
	statsAdozioniCmd.Flags().IntVar(&statsLimit, "limit", 0, "Max risultati (default 50)")

	statsCmd.AddCommand(statsAdozioniCmd)
	rootCmd.AddCommand(statsCmd)
}
```

**Step 3: Build and test**

Run: `cd /home/paolotax/rails_2023/scagnozz-cli && go build ./cmd/scagnozz/`
Expected: builds without errors

**Step 4: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add internal/mcp/tools.go internal/commands/stats.go
git commit -m "feat: stats_adozioni MCP tool and CLI command"
```

---

### Task 6: Update Scagnozz skill

**Files:**
- Modify: `/home/paolotax/.claude/skills/scagnozz/SKILL.md`

**Step 1: Add stats section to the skill**

After the `### Documenti / Ordini` section, add:

```markdown
### Statistiche adozioni

```bash
# Classifica editori in una provincia
scagnozz stats adozioni --group-by editore --provincia TO

# Classifica editori per materia e classe
scagnozz stats adozioni --group-by editore,disciplina --provincia TO --classe 3

# Dove è adottato un titolo (ricerca parziale)
scagnozz stats adozioni --group-by provincia --titolo "PEPPER 1"

# Confronto province
scagnozz stats adozioni --group-by provincia

# Dettaglio scuole per un editore
scagnozz stats adozioni --group-by scuola --provincia TO --editore PEARSON

# Classifica titoli per materia
scagnozz stats adozioni --group-by titolo --provincia TO --disciplina MATEMATICA --classe 3

# Con coefficiente personalizzato (alunni per classe)
scagnozz stats adozioni --group-by editore --provincia TO --coefficiente 25
```

Dimensioni `group_by` combinabili: editore, disciplina, classe, provincia, titolo, scuola.
Filtri combinabili: provincia, regione, classe, editore, disciplina, titolo (parziale), isbn, combinazione.
Metriche: classi_count, scuole_count, copie_stimate, importo_cents, percentuale.
Solo elementari, solo da acquistare.
```

**Step 2: Commit**

```bash
git add /home/paolotax/.claude/skills/scagnozz/SKILL.md
git commit -m "docs: add stats adozioni commands to Scagnozz skill"
```
