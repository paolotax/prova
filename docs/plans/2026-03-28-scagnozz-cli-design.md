# Scagnozz CLI — Design Document

## Overview

CLI in Go per interagire con Scagnozz da terminale e AI agent (Claude Code, Cursor, GPT, Gemini).
Pattern ispirato a fizzy-cli: output JSON strutturato con envelope, skill embedded, setup interattivo.

## MVP Scope

5 comandi: `setup`, `search`, `appunto create`, `skill`, `help`.
1 nuovo endpoint Rails: `GET /api/v1/me`.

## Project Structure

```
scagnozz-cli/
  cmd/scagnozz/main.go           # Entry point
  internal/
    commands/
      root.go                     # Config loading, auth, output helpers (printList, printDetail, printMutation)
      setup.go                    # scagnozz setup — wizard token + url
      search.go                   # scagnozz search "<query>" [--type scuola|cliente|classe|persona]
      appunto.go                  # scagnozz appunto create --appuntabile "Scuola:<id>" --nome "..." [--content "..."]
      skill.go                    # scagnozz skill — installa SKILL.md in AI agents
    client/
      client.go                   # HTTP client: Bearer token, retry (3x backoff), timeout 10s
    config/
      config.go                   # YAML config load/save (~/.config/scagnozz/config.yaml)
    render/
      render.go                   # TTY styled output vs JSON envelope
  skills/scagnozz/SKILL.md        # Embedded via go:embed
  scripts/install.sh              # Curl-pipe installer
  go.mod
  go.sum
```

## Commands

### scagnozz setup

Interactive wizard:
1. Prompt URL del server (default: https://scagnozz.com)
2. Prompt Access Token
3. Chiama `GET /api/v1/me` per verificare
4. Salva in `~/.config/scagnozz/config.yaml` (permessi 0600)

```yaml
url: https://scagnozz.com
token: Uve9qRKtZ3DTss9YtDkKagPd
```

### scagnozz search

```bash
scagnozz search "zibordi"                    # Tutti i tipi
scagnozz search "zibordi" --type scuola       # Solo scuole
scagnozz search "rossi" --type persona        # Solo persone
scagnozz search "zibordi" --limit 10          # Max risultati
```

Chiama: `GET /api/v1/search?q=<query>&type=<type>&limit=<limit>`

### scagnozz appunto create

```bash
scagnozz appunto create \
  --appuntabile "Scuola:e6a78e43-..." \
  --nome "Visita programmata" \
  --content "Passare lunedi per cataloghi"
```

Chiama: `POST /api/v1/appunti`

### scagnozz skill

Installa SKILL.md negli AI agent. Modalita:
- Interattiva: prompt per scegliere target (Claude Code, Cursor, stdout)
- Non-interattiva: stampa su stdout

Target:
- Claude Code: `~/.claude/skills/scagnozz/SKILL.md`
- Cursor: `.cursor/skills/scagnozz/SKILL.md`

## JSON Envelope

Ogni comando produce output con questo formato:

```json
{
  "ok": true,
  "data": [...],
  "summary": "3 scuole trovate per 'zibordi'",
  "breadcrumbs": [
    {"cmd": "scagnozz appunto create --appuntabile <value>", "label": "Crea appunto"}
  ]
}
```

Errori:
```json
{
  "ok": false,
  "error": "Token non valido",
  "breadcrumbs": [
    {"cmd": "scagnozz setup", "label": "Riconfigura autenticazione"}
  ]
}
```

## Output Modes

- TTY → styled con colori (lipgloss)
- Piped / `--agent` flag → JSON puro
- Deteczione automatica via `os.Stdout.Fd()` + `isatty`

## Authentication

Config priority:
1. CLI flags: `--token`, `--url`
2. Environment: `SCAGNOZZ_TOKEN`, `SCAGNOZZ_URL`
3. Config file: `~/.config/scagnozz/config.yaml`

HTTP: `Authorization: Bearer <token>` su ogni richiesta.

## HTTP Client

- Timeout: 10s
- Retry: 3 tentativi con exponential backoff (1s, 2s, 4s)
- Retry su: 429 (rispetta Retry-After), 5xx
- No retry su: POST non-idempotenti (appunto create)

## Rails Changes

### Nuovo endpoint: GET /api/v1/me

```ruby
# app/controllers/api/v1/me_controller.rb
class Api::V1::MeController < Api::V1::BaseController
  def show
    render json: {
      email: Current.user.email,
      name: Current.user.name,
      account: Current.account.name,
      account_id: Current.account.id
    }
  end
end
```

Route: `get "me", to: "me#show"` dentro `namespace :api / namespace :v1`.

### Endpoint esistenti (nessuna modifica)

- `GET /api/v1/search` — search scuole, clienti, classi, persone
- `POST /api/v1/appunti` — crea appunto

## SKILL.md Content

```markdown
# Scagnozz CLI

Gestione ordini scuola e clienti via terminale.

## Comandi

### Cerca
scagnozz search "<query>"                # Cerca tutto
scagnozz search "<query>" --type scuola   # Solo scuole

### Appunti
scagnozz appunto create --appuntabile "Scuola:<id>" --nome "Titolo" --content "Testo"

## Flusso tipico
1. Cerca: scagnozz search "zibordi"
2. Usa appuntabile_value dal risultato
3. Crea appunto: scagnozz appunto create --appuntabile "Scuola:uuid" --nome "Visita"

## Output
JSON con: ok, data, summary, breadcrumbs.
Usa --agent per forzare output JSON.
```

## Go Dependencies

- `spf13/cobra` — CLI framework
- `charmbracelet/huh` — interactive prompts
- `charmbracelet/lipgloss` — styled terminal output
- `gopkg.in/yaml.v3` — config files

## Distribution

- Cross-compiled: Linux (amd64/arm64), macOS (amd64/arm64), Windows
- Install: `curl -fsSL https://scagnozz.com/cli/install.sh | bash && scagnozz setup`
- Alternativa: release binari su GitHub

## Future Extensions

- `scagnozz appunto list` — lista appunti con filtri
- `scagnozz appunto show <id>` — dettaglio appunto
- `scagnozz ordine create` — crea ordine con righe
- `scagnozz ordine list` — lista ordini
- `scagnozz libro search` — cerca libri per ISBN/titolo
- Risorse MCP-style (read-only queries su dati account)
