# Stats Adozioni API + MCP Tool

Data: 2026-04-03

## Obiettivo

Endpoint API flessibile per statistiche adozioni elementari con aggregamenti dinamici, consumato dal CLI Scagnozz (MCP tool) e dall'AI agent. Sostituisce le query SQL editabili nel modello Stat.

## Endpoint

```
GET /api/v1/stats/adozioni
```

Autenticazione: Bearer token (stessa auth esistente API v1).

### Filtri (tutti opzionali, combinabili)

| Parametro | Tipo | Esempio | Note |
|-----------|------|---------|------|
| provincia | string | `TO` | Codice provincia |
| regione | string | `PIEMONTE` | Nome regione |
| classe | string | `3` | Anno corso (1-5) |
| editore | string | `PEARSON` | Nome editore |
| disciplina | string | `MATEMATICA` | Materia |
| titolo | string | `PEPPER 1` | Ricerca parziale (ILIKE) |
| isbn | string | `9788891...` | Codice ISBN |
| combinazione | string | `40 ORE SETTIMANALI` | Tempo scuola |

### Aggregamento

| Parametro | Tipo | Obbligatorio | Note |
|-----------|------|-------------|------|
| group_by | string | si | Combinazione di: `editore`, `disciplina`, `classe`, `provincia`, `titolo`, `scuola` separati da virgola |
| coefficiente | integer | no | Alunni per classe per stima copie (default 18) |
| order_by | string | no | Campo ordinamento: `classi_count` (default), `adozioni_count`, `percentuale`, `importo` |
| limit | integer | no | Max risultati (default 50) |

### Risposta

```json
{
  "filters_applied": { "provincia": "TO", "classe": "3" },
  "group_by": ["editore", "disciplina"],
  "coefficiente": 18,
  "totals": {
    "classi_count": 1200,
    "scuole_count": 340,
    "copie_stimate": 21600,
    "importo_cents": 3456000
  },
  "results": [
    {
      "editore": "PEARSON",
      "disciplina": "MATEMATICA",
      "classi_count": 450,
      "scuole_count": 120,
      "adozioni_count": 450,
      "copie_stimate": 8100,
      "importo_cents": 1296000,
      "percentuale": 37.5
    }
  ]
}
```

- `percentuale` = `classi_count / totals.classi_count * 100`
- `totals` calcolati con stessi filtri ma senza group_by
- Quando `group_by` include `titolo`: aggiunge `isbn`, `autori`, `prezzo` per riga
- Quando `group_by` include `scuola`: aggiunge `denominazione`, `provincia` per riga

### Esempi di utilizzo

```
# Classifica editori matematica classe 3 a Torino
GET /api/v1/stats/adozioni?provincia=TO&classe=3&disciplina=MATEMATICA&group_by=editore

# Dove e adottato Pepper 1
GET /api/v1/stats/adozioni?titolo=PEPPER 1&group_by=provincia

# Confronto province per numero classi
GET /api/v1/stats/adozioni?group_by=provincia

# Dettaglio scuole con un editore specifico
GET /api/v1/stats/adozioni?provincia=TO&editore=PEARSON&group_by=scuola

# Classifica titoli per materia in una provincia
GET /api/v1/stats/adozioni?provincia=TO&disciplina=MATEMATICA&classe=3&group_by=titolo
```

## Architettura Rails

### Model: `Stats::AdozioniQuery`

File: `app/models/stats/adozioni_query.rb`

Query builder che genera SQL dinamico su `import_adozioni` JOIN `import_scuole` JOIN `tipi_scuole`.

Filtri hardcoded:
- `tipi_scuole.grado = 'E'` (solo elementari)
- `import_adozioni."DAACQUIST" = 'Si'` (solo da acquistare)

```ruby
class Stats::AdozioniQuery
  DIMENSIONS = {
    editore:    'ia."EDITORE"',
    disciplina: 'ia."DISCIPLINA"',
    classe:     'ia."ANNOCORSO"',
    provincia:  'isc."PROVINCIA"',
    titolo:     'ia."TITOLO"',
    scuola:     'isc."CODICESCUOLA"'
  }.freeze

  # Colonne extra quando group_by include titolo o scuola
  EXTRA_COLUMNS = {
    titolo: ['ia."CODICEISBN" as isbn', 'ia."AUTORI" as autori',
             'ia."PREZZO" as prezzo'],
    scuola: ['isc."DENOMINAZIONESCUOLA" as denominazione',
             'isc."PROVINCIA" as provincia']
  }.freeze

  def initialize(filters:, group_by:, coefficiente: 18, order_by: :classi_count, limit: 50)
  end

  def call
    { filters_applied:, group_by:, coefficiente:, totals:, results: }
  end

  private

  # Query base:
  # SELECT {group_by_columns}, {extra_columns},
  #   COUNT(DISTINCT (ia."CODICESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO")) as classi_count,
  #   COUNT(DISTINCT ia."CODICESCUOLA") as scuole_count,
  #   COUNT(*) as adozioni_count,
  #   COUNT(DISTINCT (ia."CODICESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO")) * :coefficiente as copie_stimate,
  #   SUM(CAST(REPLACE(ia."PREZZO", ',', '.') AS numeric)) *
  #     COUNT(DISTINCT (ia."CODICESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO")) * :coefficiente / COUNT(*) as importo
  # FROM import_adozioni ia
  # INNER JOIN import_scuole isc ON isc."CODICESCUOLA" = ia."CODICESCUOLA"
  # INNER JOIN tipi_scuole ts ON ts.tipo = isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
  # WHERE ts.grado = 'E' AND ia."DAACQUIST" = 'Si'
  #   {dynamic filters}
  # GROUP BY {group_by_columns}
  # ORDER BY {order_by} DESC
  # LIMIT :limit

  # Totals: stessa query senza GROUP BY, senza LIMIT
end
```

Filtri dinamici:
- `provincia` → `isc."PROVINCIA" = ?`
- `regione` → `isc."REGIONE" = ?`
- `classe` → `ia."ANNOCORSO" = ?`
- `editore` → `ia."EDITORE" = ?`
- `disciplina` → `ia."DISCIPLINA" = ?`
- `titolo` → `ia."TITOLO" ILIKE ?` (con `%` prefix/suffix)
- `isbn` → `ia."CODICEISBN" = ?`
- `combinazione` → `ia."COMBINAZIONE" = ?`

### Controller: `Api::V1::Stats::AdozioniController`

File: `app/controllers/api/v1/stats/adozioni_controller.rb`

```ruby
module Api::V1::Stats
  class AdozioniController < Api::V1::BaseController
    def index
      query = Stats::AdozioniQuery.new(
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
```

### Route

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :stats do
      get :adozioni, to: "adozioni#index"
    end
  end
end
```

## Scagnozz CLI (Go)

### MCP Tool

File: `internal/mcp/tools.go` — aggiungere `registerStatsAdozioni`

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
```

Description tool:
```
"Statistiche adozioni elementari con aggregamenti flessibili.
Filtra per provincia, classe, editore, disciplina, titolo (parziale), isbn.
Aggrega con group_by: editore, disciplina, classe, provincia, titolo, scuola.
Restituisce conteggio classi, scuole, copie stimate, importo e percentuale sul totale filtrato."
```

### Comando CLI

File: `internal/commands/stats.go`

```bash
scagnozz stats adozioni --provincia TO --classe 3 --group-by editore,disciplina
scagnozz stats adozioni --titolo "PEPPER 1" --group-by provincia
scagnozz stats adozioni --group-by provincia --order-by copie_stimate --limit 20
```

## Decisioni

- **Query dirette** su import_adozioni + import_scuole, no materialized view (flessibilita aggregamenti)
- **Solo elementari** hardcoded per ora (`grado = 'E'`)
- **Titolo ILIKE** per ricerca parziale — l'AI del CLI interpreta e passa la stringa
- **Percentuale** = classi_count del gruppo / classi_count totale con stessi filtri
- **Coefficiente** configurabile (default 18) per stima copie e importo
- **Model in app/models/stats/** separato da AdozioniAnalytics (che e user-centric)

## Ordine di implementazione

1. `Stats::AdozioniQuery` model + test
2. `Api::V1::Stats::AdozioniController` + test integration
3. Tool MCP `stats_adozioni` in scagnozz-cli
4. Comando CLI `scagnozz stats adozioni`
5. Aggiornare skill Scagnozz con nuovi comandi
