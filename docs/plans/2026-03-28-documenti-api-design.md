# Documenti API — Design Document

## Overview

Endpoint per creare documenti (ordini, DDT, fatture) con righe via CLI/agent. L'agent cerca i libri e il destinatario, poi manda righe strutturate al server. Il server calcola prezzi e totali.

## Endpoints

### GET /api/v1/libri

Ricerca libri per titolo o ISBN.

Parametri: `q` (testo/ISBN), `limit` (default 10, max 50).

Response:
```json
{
  "results": [
    {
      "id": "uuid",
      "titolo": "Tutto Vacanze Italiano 1",
      "codice_isbn": "9788891234567",
      "prezzo_cents": 890,
      "prezzo": "8.90",
      "editore": "Giunti"
    }
  ],
  "count": 3
}
```

### POST /api/v1/documenti

Crea documento con righe.

Request:
```json
{
  "clientable_value": "Scuola:uuid",
  "causale": "Ordine Scuola",
  "note": "Ordine vacanze",
  "righe": [
    {"libro_id": "uuid", "quantita": 5, "sconto": 20},
    {"libro_id": "uuid", "quantita": 5, "sconto": 20, "prezzo_cents": 400}
  ]
}
```

Server logic:
1. Risolve `clientable_value` (Scuola, Cliente, Persona)
2. Trova causale per nome (fuzzy match su campo `causale`)
3. Per ogni riga: se `prezzo_cents` non passato, usa `libro.prezzo_in_cents` e applica sconto
4. Calcola totali documento

Response:
```json
{
  "ok": true,
  "documento_id": "uuid",
  "numero_documento": "ORD-2026-042",
  "causale": "Ordine Scuola",
  "clientable": "G. ZIBORDI",
  "totale": "44.50",
  "totale_copie": 10,
  "righe_count": 2
}
```

Causali supportate: Ordine Scuola, Ordine Cliente, TD01 (fattura), TD04 (nota credito), DDT, Campionario, saggi, ecc.

## CLI

```bash
# Cerca libri
scagnozz libri search "tutto vacanze italiano"
scagnozz libri search "9788891234567"

# Crea documento
scagnozz documento create \
  --clientable "Scuola:uuid" \
  --causale "Ordine Scuola" \
  --riga "libro_id:uuid,quantita:10,sconto:20" \
  --riga "libro_id:uuid,quantita:5,prezzo:400"
```

## Flusso agent

### Esempio 1: "10 copie di strategie invalsi unico sconto 20 a contabile di reggio"

1. `scagnozz libri search "strategie invalsi unico"` → libro_id
2. `scagnozz search "contabile reggio" --type cliente` → clientable_value
3. `scagnozz documento create --clientable "Cliente:uuid" --causale "Ordine Cliente" --riga "libro_id:uuid,quantita:10,sconto:20"`

### Esempio 2: "5 copie x tutto vacanze italiano e matematica dalla 1 alla 5 per Mara delle Zibordi, 4 euro a copia"

1. Cerca 10 libri (italiano 1-5 + matematica 1-5)
2. `scagnozz search "mara zibordi" --type persona` → persona
3. Crea documento con 10 righe, ognuna quantita:5, prezzo_cents:400

## SKILL.md (aggiunta)

```markdown
### Libri
scagnozz libri search "<titolo o ISBN>"

### Documenti / Ordini
scagnozz documento create --clientable "<value>" --causale "<tipo>" \
  --riga "libro_id:<id>,quantita:<n>,sconto:<pct>" \
  --riga "libro_id:<id>,quantita:<n>,prezzo:<cents>"

Causali: Ordine Scuola, Ordine Cliente, TD01, TD04, DDT, Campionario, saggi

## Flusso ordini
1. Cerca i libri: scagnozz libri search "<titolo>"
2. Cerca il destinatario: scagnozz search "<nome>"
3. Crea il documento con le righe
4. Per ordini con più libri, cerca ogni libro e aggiungi una --riga per ciascuno
```

## Implementation

### Rails
- `app/controllers/api/v1/libri_controller.rb` — GET /api/v1/libri (search)
- `app/controllers/api/v1/documenti_controller.rb` — POST /api/v1/documenti (create)
- `app/models/documenti/creator.rb` — PORO per creazione documento con righe
- Route: risorse libri e documenti in namespace api/v1

### Go (scagnozz-cli)
- `internal/commands/libri.go` — scagnozz libri search
- `internal/commands/documento.go` — scagnozz documento create
- `skills/scagnozz/SKILL.md` — aggiornare

### OpenAPI
- `public/api/openapi.json` — aggiungere endpoint libri e documenti
