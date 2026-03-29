# Scagnozz MCP Server Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `scagnozz mcp` subcommand that runs a stdio-based MCP server, exposing all CLI functionality as MCP tools for AI desktop apps (Claude Desktop, Cursor, etc.)

**Architecture:** New `internal/mcp/` package with server setup and tool handlers. Each tool reuses the existing `client.Client` for API calls. The `mcp` cobra command loads config, creates the client, and starts the stdio server. No SSE, no OAuth — just stdio + bearer token from existing config.

**Tech Stack:** `github.com/modelcontextprotocol/go-sdk/mcp` (official Go MCP SDK), existing `internal/client` and `internal/config` packages.

---

### Task 1: Add MCP SDK dependency

**Files:**
- Modify: `/home/paolotax/rails_2023/scagnozz-cli/go.mod`

**Step 1: Add the dependency**

Run:
```bash
cd /home/paolotax/rails_2023/scagnozz-cli && go get github.com/modelcontextprotocol/go-sdk@latest
```

**Step 2: Verify it resolves**

Run: `cd /home/paolotax/rails_2023/scagnozz-cli && go mod tidy`
Expected: no errors, go.sum updated

**Step 3: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add go.mod go.sum
git commit -m "feat: add MCP Go SDK dependency"
```

---

### Task 2: Create MCP server package with search tool

**Files:**
- Create: `internal/mcp/server.go`
- Create: `internal/mcp/tools.go`

**Step 1: Create `internal/mcp/server.go`**

This file initializes the MCP server and registers all tools.

```go
package mcp

import (
	"context"

	"github.com/modelcontextprotocol/go-sdk/mcp"
	"github.com/paolotax/scagnozz-cli/internal/client"
)

func RunServer(ctx context.Context, apiClient *client.Client, version string) error {
	server := mcp.NewServer(
		&mcp.Implementation{
			Name:    "scagnozz",
			Version: version,
		},
		nil,
	)

	registerTools(server, apiClient)

	return server.Run(ctx, &mcp.StdioTransport{})
}
```

**Step 2: Create `internal/mcp/tools.go`**

Start with just the search tool to validate the pattern works end-to-end.

```go
package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"

	gomcp "github.com/modelcontextprotocol/go-sdk/mcp"
	"github.com/paolotax/scagnozz-cli/internal/client"
)

func registerTools(server *gomcp.Server, apiClient *client.Client) {
	registerSearch(server, apiClient)
}

// --- search ---

type SearchInput struct {
	Query string `json:"query" jsonschema:"description=Testo di ricerca (minimo 2 caratteri)"`
	Type  string `json:"type,omitempty" jsonschema:"description=Filtra per tipo: scuola\\, cliente\\, classe\\, persona"`
	Limit int    `json:"limit,omitempty" jsonschema:"description=Numero massimo di risultati (1-20)"`
}

func registerSearch(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "search",
		Description: "Cerca scuole, clienti, classi e persone nel database Scagnozz. Restituisce risultati con appuntabile_value da usare per creare appunti o documenti.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args SearchInput) (*gomcp.CallToolResult, any, error) {
		params := url.Values{}
		params.Set("q", args.Query)
		if args.Type != "" {
			params.Set("type", args.Type)
		}
		if args.Limit > 0 {
			params.Set("limit", fmt.Sprintf("%d", args.Limit))
		}

		data, err := apiClient.Get("/api/v1/search", params)
		if err != nil {
			return errResult(err), nil, nil
		}

		return jsonResult(data), nil, nil
	})
}

// --- helpers ---

func jsonResult(data json.RawMessage) *gomcp.CallToolResult {
	return &gomcp.CallToolResult{
		Content: []gomcp.Content{
			&gomcp.TextContent{Text: string(data)},
		},
	}
}

func errResult(err error) *gomcp.CallToolResult {
	return &gomcp.CallToolResult{
		Content: []gomcp.Content{
			&gomcp.TextContent{Text: fmt.Sprintf("Errore: %s", err.Error())},
		},
		IsError: true,
	}
}
```

**Step 3: Verify it compiles**

Run: `cd /home/paolotax/rails_2023/scagnozz-cli && go build ./...`
Expected: no errors

**Step 4: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add internal/mcp/
git commit -m "feat: MCP server package with search tool"
```

---

### Task 3: Add `mcp` cobra command

**Files:**
- Create: `internal/commands/mcp.go`

**Step 1: Create the command**

```go
package commands

import (
	"context"
	"fmt"

	mcpserver "github.com/paolotax/scagnozz-cli/internal/mcp"
	"github.com/spf13/cobra"
)

var mcpCmd = &cobra.Command{
	Use:   "mcp",
	Short: "Avvia server MCP (stdio) per AI desktop apps",
	Long:  "Avvia un server MCP in modalità stdio. Usare con Claude Desktop, Cursor, o altri client MCP.",
	RunE: func(cmd *cobra.Command, args []string) error {
		if apiClient == nil {
			return fmt.Errorf("configurazione mancante — esegui 'scagnozz setup' prima")
		}
		return mcpserver.RunServer(context.Background(), apiClient, version)
	},
}

func init() {
	rootCmd.AddCommand(mcpCmd)
}
```

**Step 2: Verify it compiles**

Run: `cd /home/paolotax/rails_2023/scagnozz-cli && go build ./...`
Expected: no errors

**Step 3: Build and test manually**

Run:
```bash
cd /home/paolotax/rails_2023/scagnozz-cli && go build -o /tmp/scagnozz-mcp ./cmd/scagnozz/
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | /tmp/scagnozz-mcp mcp
```

Expected: JSON-RPC response with server info and tool list containing "search".

**Step 4: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add internal/commands/mcp.go
git commit -m "feat: add 'scagnozz mcp' command for stdio server"
```

---

### Task 4: Add remaining read tools (persone, libri, me)

**Files:**
- Modify: `internal/mcp/tools.go`

**Step 1: Add persone, libri_search, and me tools**

Append to `tools.go`:

```go
// Add to registerTools:
//   registerPersone(server, apiClient)
//   registerLibriSearch(server, apiClient)
//   registerMe(server, apiClient)

// --- persone ---

type PersoneInput struct {
	AnnCorso string `json:"anno_corso,omitempty" jsonschema:"description=Filtra per anno corso delle classi (es. 3 o 3\\,5)"`
	ConEmail bool   `json:"con_email,omitempty" jsonschema:"description=Solo persone con email"`
	ScuolaID string `json:"scuola_id,omitempty" jsonschema:"description=Filtra per scuola (UUID)"`
	Query    string `json:"query,omitempty" jsonschema:"description=Cerca per nome o cognome"`
	Limit    int    `json:"limit,omitempty" jsonschema:"description=Numero massimo di risultati (1-200\\, default 50)"`
	Recenti  bool   `json:"recenti,omitempty" jsonschema:"description=Ordina per data creazione (più recenti prima)"`
}

func registerPersone(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "persone",
		Description: "Lista insegnanti e persone con filtri. Filtra per anno corso, email, scuola o nome. Restituisce appuntabile_value per creare appunti.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args PersoneInput) (*gomcp.CallToolResult, any, error) {
		params := url.Values{}
		if args.AnnCorso != "" {
			params.Set("anno_corso", args.AnnCorso)
		}
		if args.ConEmail {
			params.Set("con_email", "true")
		}
		if args.ScuolaID != "" {
			params.Set("scuola_id", args.ScuolaID)
		}
		if args.Query != "" {
			params.Set("q", args.Query)
		}
		if args.Limit > 0 {
			params.Set("limit", fmt.Sprintf("%d", args.Limit))
		}
		if args.Recenti {
			params.Set("sort", "recenti")
		}

		data, err := apiClient.Get("/api/v1/persone", params)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}

// --- libri_search ---

type LibriSearchInput struct {
	Query string `json:"query" jsonschema:"description=Titolo o ISBN del libro da cercare"`
	Limit int    `json:"limit,omitempty" jsonschema:"description=Numero massimo di risultati (1-50)"`
}

func registerLibriSearch(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "libri_search",
		Description: "Cerca libri per titolo o ISBN. Restituisce id e dettagli da usare per creare ordini.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args LibriSearchInput) (*gomcp.CallToolResult, any, error) {
		params := url.Values{}
		params.Set("q", args.Query)
		if args.Limit > 0 {
			params.Set("limit", fmt.Sprintf("%d", args.Limit))
		}

		data, err := apiClient.Get("/api/v1/libri", params)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}

// --- me ---

type MeInput struct{}

func registerMe(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "me",
		Description: "Verifica identità: restituisce utente e account associati al token.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args MeInput) (*gomcp.CallToolResult, any, error) {
		data, err := apiClient.Get("/api/v1/me", nil)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}
```

**Step 2: Verify it compiles**

Run: `cd /home/paolotax/rails_2023/scagnozz-cli && go build ./...`

**Step 3: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add internal/mcp/tools.go
git commit -m "feat: add persone, libri_search, me MCP tools"
```

---

### Task 5: Add write tools (appunto_create, documento_create, persone_import)

**Files:**
- Modify: `internal/mcp/tools.go`

**Step 1: Add appunto_create tool**

```go
// Add to registerTools:
//   registerAppuntoCreate(server, apiClient)

type AppuntoCreateInput struct {
	AppuntabileValue string `json:"appuntabile_value" jsonschema:"description=Destinatario nel formato Tipo:UUID (es. Scuola:uuid\\, Cliente:uuid\\, Persona:uuid). Ottenibile da search o persone."`
	Nome             string `json:"nome,omitempty" jsonschema:"description=Titolo dell'appunto"`
	Content          string `json:"content,omitempty" jsonschema:"description=Contenuto testuale dell'appunto"`
	Publish          *bool  `json:"publish,omitempty" jsonschema:"description=Se true pubblica subito (default true)"`
}

func registerAppuntoCreate(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "appunto_create",
		Description: "Crea un appunto (nota) associato a una scuola, cliente o persona. Usa appuntabile_value ottenuto dalla ricerca.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args AppuntoCreateInput) (*gomcp.CallToolResult, any, error) {
		body := map[string]any{
			"appuntabile_value": args.AppuntabileValue,
		}
		if args.Nome != "" {
			body["nome"] = args.Nome
		}
		if args.Content != "" {
			body["content"] = args.Content
		}
		if args.Publish != nil {
			body["publish"] = *args.Publish
		}

		data, err := apiClient.Post("/api/v1/appunti", body)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}
```

**Step 2: Add documento_create tool**

```go
// Add to registerTools:
//   registerDocumentoCreate(server, apiClient)

type DocumentoRiga struct {
	LibroID     string `json:"libro_id,omitempty" jsonschema:"description=UUID del libro"`
	CodiceISBN  string `json:"codice_isbn,omitempty" jsonschema:"description=ISBN del libro (il server risolve il libro)"`
	Titolo      string `json:"titolo,omitempty" jsonschema:"description=Titolo del libro (il server risolve il libro)"`
	Quantita    int    `json:"quantita" jsonschema:"description=Quantità"`
	Sconto      int    `json:"sconto,omitempty" jsonschema:"description=Percentuale di sconto"`
	PrezzoCents int    `json:"prezzo_cents,omitempty" jsonschema:"description=Prezzo in centesimi (es. 850 = 8.50€)"`
}

type DocumentoCreateInput struct {
	ClientableValue string          `json:"clientable_value" jsonschema:"description=Destinatario nel formato Tipo:UUID (es. Scuola:uuid\\, Cliente:uuid)"`
	Causale         string          `json:"causale" jsonschema:"description=Tipo documento: Ordine Scuola\\, Ordine Cliente\\, TD01\\, TD04\\, DDT\\, Campionario\\, saggi"`
	Righe           []DocumentoRiga `json:"righe,omitempty" jsonschema:"description=Righe del documento. Ogni riga identifica il libro per libro_id\\, codice_isbn o titolo."`
	Note            string          `json:"note,omitempty" jsonschema:"description=Note documento"`
	DataDocumento   string          `json:"data_documento,omitempty" jsonschema:"description=Data documento (YYYY-MM-DD)"`
	NumeroDocumento string          `json:"numero_documento,omitempty" jsonschema:"description=Numero documento"`
	DDTNumero       string          `json:"ddt_numero,omitempty" jsonschema:"description=Numero DDT padre"`
	SpeseCents      string          `json:"spese_cents,omitempty" jsonschema:"description=Spese di porto in centesimi (es. 580 = 5.80€)"`
}

func registerDocumentoCreate(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "documento_create",
		Description: "Crea un documento (ordine, DDT, fattura) con righe. Cerca prima i libri con libri_search e il destinatario con search.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args DocumentoCreateInput) (*gomcp.CallToolResult, any, error) {
		body := map[string]any{
			"clientable_value": args.ClientableValue,
			"causale":          args.Causale,
		}
		if len(args.Righe) > 0 {
			righe := make([]map[string]any, len(args.Righe))
			for i, r := range args.Righe {
				riga := map[string]any{}
				if r.LibroID != "" {
					riga["libro_id"] = r.LibroID
				}
				if r.CodiceISBN != "" {
					riga["codice_isbn"] = r.CodiceISBN
				}
				if r.Titolo != "" {
					riga["titolo"] = r.Titolo
				}
				if r.Quantita > 0 {
					riga["quantita"] = r.Quantita
				}
				if r.Sconto > 0 {
					riga["sconto"] = r.Sconto
				}
				if r.PrezzoCents > 0 {
					riga["prezzo_cents"] = r.PrezzoCents
				}
				righe[i] = riga
			}
			body["righe"] = righe
		}
		if args.Note != "" {
			body["note"] = args.Note
		}
		if args.DataDocumento != "" {
			body["data_documento"] = args.DataDocumento
		}
		if args.NumeroDocumento != "" {
			body["numero_documento"] = args.NumeroDocumento
		}
		if args.DDTNumero != "" {
			body["ddt_numero"] = args.DDTNumero
		}
		if args.SpeseCents != "" {
			body["spese_cents"] = args.SpeseCents
		}

		data, err := apiClient.Post("/api/v1/documenti", body)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}
```

**Step 3: Add persone_import tool**

```go
// Add to registerTools:
//   registerPersoneImport(server, apiClient)

type PersoneImportInput struct {
	Cognome   string   `json:"cognome" jsonschema:"description=Cognome (obbligatorio)"`
	Nome      string   `json:"nome,omitempty" jsonschema:"description=Nome"`
	Email     string   `json:"email,omitempty" jsonschema:"description=Email"`
	Cellulare string   `json:"cellulare,omitempty" jsonschema:"description=Cellulare"`
	Telefono  string   `json:"telefono,omitempty" jsonschema:"description=Telefono"`
	Scuola    string   `json:"scuola,omitempty" jsonschema:"description=Nome scuola (fuzzy match sul server)"`
	Classi    []string `json:"classi,omitempty" jsonschema:"description=Lista classi (es. [\"3A\"\\, \"5B\"])"`
	Ruolo     string   `json:"ruolo,omitempty" jsonschema:"description=Ruolo: docente\\, dirigente\\, segretario\\, referente\\, altro"`
}

func registerPersoneImport(server *gomcp.Server, apiClient *client.Client) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "persone_import",
		Description: "Importa una persona (insegnante) con fuzzy match su scuola e classi. Gestisce automaticamente duplicati: se la persona esiste aggiorna campi vuoti e aggiunge classi.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, args PersoneImportInput) (*gomcp.CallToolResult, any, error) {
		body := map[string]any{
			"cognome": args.Cognome,
		}
		if args.Nome != "" {
			body["nome"] = args.Nome
		}
		if args.Email != "" {
			body["email"] = args.Email
		}
		if args.Cellulare != "" {
			body["cellulare"] = args.Cellulare
		}
		if args.Telefono != "" {
			body["telefono"] = args.Telefono
		}
		if args.Scuola != "" {
			body["scuola"] = args.Scuola
		}
		if len(args.Classi) > 0 {
			body["classi"] = args.Classi
		}
		if args.Ruolo != "" {
			body["ruolo"] = args.Ruolo
		}

		data, err := apiClient.Post("/api/v1/persone/import", body)
		if err != nil {
			return errResult(err), nil, nil
		}
		return jsonResult(data), nil, nil
	})
}
```

**Step 2: Update registerTools to wire everything**

```go
func registerTools(server *gomcp.Server, apiClient *client.Client) {
	registerSearch(server, apiClient)
	registerPersone(server, apiClient)
	registerLibriSearch(server, apiClient)
	registerMe(server, apiClient)
	registerAppuntoCreate(server, apiClient)
	registerDocumentoCreate(server, apiClient)
	registerPersoneImport(server, apiClient)
}
```

**Step 3: Verify it compiles**

Run: `cd /home/paolotax/rails_2023/scagnozz-cli && go build ./...`

**Step 4: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add internal/mcp/tools.go
git commit -m "feat: add appunto_create, documento_create, persone_import MCP tools"
```

---

### Task 6: Build, test end-to-end, and install

**Step 1: Build the binary**

Run:
```bash
cd /home/paolotax/rails_2023/scagnozz-cli
go build -ldflags "-X github.com/paolotax/scagnozz-cli/internal/commands.version=0.3.0" -o dist/scagnozz ./cmd/scagnozz/
cp dist/scagnozz ~/.local/bin/scagnozz
```

**Step 2: Test MCP server responds to initialize**

Run:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | scagnozz mcp
```

Expected: JSON-RPC response with `serverInfo.name: "scagnozz"` and `tools` list.

**Step 3: Test tools/list**

Run:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | scagnozz mcp
```

Expected: 7 tools listed (search, persone, libri_search, me, appunto_create, documento_create, persone_import).

**Step 4: Test a real tool call (search)**

Run:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search","arguments":{"query":"zibordi"}}}\n' | scagnozz mcp
```

Expected: JSON response with search results.

**Step 5: Commit**

```bash
cd /home/paolotax/rails_2023/scagnozz-cli
git add -A
git commit -m "feat: scagnozz mcp v0.3.0 — stdio MCP server"
```

---

### Task 7: Configure Claude Code MCP

**Files:**
- Modify: `/home/paolotax/.claude/settings.json` (or project settings)

**Step 1: Remove old scagnozz-local MCP config**

Clean up the broken SSE-based MCP from `.credentials.json` — remove the `mcpOAuth.scagnozz-local` entry.

**Step 2: Add stdio MCP server to Claude Code settings**

Add to project `.claude/settings.json`:

```json
{
  "mcpServers": {
    "scagnozz": {
      "command": "scagnozz",
      "args": ["mcp"]
    }
  }
}
```

**Step 3: Verify in Claude Code**

Restart Claude Code and run `/mcp` to verify the scagnozz server connects and tools are listed.

**Step 4: Test a tool call from Claude Code**

Ask Claude to search for "zibordi" using the MCP tool.

---

## Notes

- The MCP server reuses the same config as the CLI (`~/.config/scagnozz/config.yaml`) — users who already ran `scagnozz setup` are ready to go
- All tools return raw JSON from the API — no reformatting needed, the LLM parses it directly
- Error responses use `IsError: true` so the LLM knows the call failed
- The `me` tool helps the LLM verify auth is working before doing real operations
- To distribute: just ship the same binary — `scagnozz mcp` works on all platforms
