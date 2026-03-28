# Persone Import — Design Document

## Overview

Endpoint per importare persone/insegnanti in Scagnozz con fuzzy match su scuola, risoluzione classi lato server, deduplicazione automatica e upsert intelligente. L'AI agent fa il parsing dei file (CSV, VCF, screenshot, testo libero), il server fa il match e l'inserimento.

## Endpoints

### POST /api/v1/persone/import

Import singola persona con dati testuali.

Request:
```json
{
  "cognome": "Rossi",
  "nome": "Maria",
  "email": "maria.rossi@scuola.edu.it",
  "cellulare": "3331234567",
  "telefono": "",
  "scuola": "zibordi",
  "classi": ["3A", "5A"]
}
```

Response:
```json
{
  "ok": true,
  "action": "updated",
  "persona": { "id": "...", "cognome": "Rossi", "nome": "Maria", "email": "..." },
  "matched_scuola": "G. ZIBORDI",
  "matched_classi": ["3A - G. ZIBORDI", "5A - G. ZIBORDI"],
  "changes": ["email aggiunta", "classe 5A aggiunta"]
}
```

`action`: `created`, `updated`, `unchanged`.

### POST /api/v1/persone/import_batch

Import multiplo. Se una riga fallisce non blocca le altre.

Request:
```json
{
  "persone": [
    {"cognome": "Rossi", "nome": "Maria", "email": "m.rossi@scuola.it", "scuola": "zibordi", "classi": ["3A"]},
    {"cognome": "Bianchi", "nome": "Luca", "scuola": "zibordi", "classi": ["5A"]}
  ]
}
```

Response:
```json
{
  "ok": true,
  "summary": "2 persone importate: 1 creata, 1 aggiornata, 0 errori",
  "results": [
    {"action": "created", "cognome": "Rossi", "nome": "Maria", "matched_scuola": "G. ZIBORDI"},
    {"action": "updated", "cognome": "Bianchi", "nome": "Luca", "matched_scuola": "G. ZIBORDI", "changes": ["classe 5A aggiunta"]}
  ],
  "errors": []
}
```

Errori per riga:
```json
{
  "index": 1,
  "cognome": "Verdi",
  "error": "scuola 'xyz' non trovata",
  "suggestions": ["G. VERDI - PIEVE MODOLENA"]
}
```

## Server Logic

### Match scuola
- Usa `search_all_word` (pg_search) sull'account corrente
- Prende il primo risultato
- Se ambiguo (più scuole con score simile) → errore con candidati
- Se nessun match → errore con suggerimenti

### Match classe
- Dentro la scuola trovata, parsa "3A" → `anno_corso: 3, sezione: "A"`
- Cerca nella tabella classi della scuola
- Se non trovata → errore

### Match duplicato persona
- Stessa `scuola_id` + `cognome` case-insensitive
- Se nome presente, lo usa per disambiguare
- Se duplicato ambiguo → errore con candidati

### Upsert
- Campi aggiornabili solo se vuoti: `email`, `cellulare`, `telefono`, `note`
- Classi: aggiunge mancanti, non rimuove esistenti
- Mai sovrascrivere un campo già compilato

## CLI Commands

```bash
# Singolo
scagnozz persone import --scuola "zibordi" --classe "3A" \
  --cognome "Rossi" --nome "Maria" --email "m.rossi@scuola.it"

# Batch
scagnozz persone import-batch --file persone.json
```

## SKILL.md (aggiunta)

```markdown
### Import persone

scagnozz persone import --scuola "zibordi" --classe "3A" \
  --cognome "Rossi" --nome "Maria" --email "m.rossi@scuola.it"

scagnozz persone import-batch --file persone.json

## Flusso import da file
1. L'utente fornisce un file (CSV, Excel, VCF, screenshot, testo)
2. Parsa il contenuto ed estrai: cognome, nome, email, cellulare, scuola, classi
3. Chiama scagnozz persone import-batch o POST /api/v1/persone/import_batch
4. Il server fa fuzzy match su scuola, risolve classi, gestisce duplicati
5. Mostra il risultato: creati, aggiornati, errori
```

## Flusso agent

1. Utente dà all'agent un file/testo/screenshot
2. L'agent parsa ed estrae: cognome, nome, email, scuola, classi
3. L'agent chiama l'endpoint batch
4. Il server fa match e upsert
5. L'agent mostra il risultato

## Implementation

### Rails (prova)
- `app/controllers/api/v1/persone_controller.rb` — aggiungere `import` e `import_batch`
- `app/services/persone_importer.rb` — logica match/upsert
- Route: `post "persone/import"` e `post "persone/import_batch"` in namespace api/v1

### Go (scagnozz-cli)
- `internal/commands/persone.go` — aggiungere subcommand `import` e `import-batch`
- `skills/scagnozz/SKILL.md` — aggiornare con istruzioni import

### OpenAPI
- `public/api/openapi.json` — aggiungere i due endpoint
