# Propaganda — andamento ritiri collane

Data: 2026-06-14
Stato: implementato

## Problema

Durante la propaganda l'utente lascia collane di libri in visione (bolle visione)
e poi le ritira. I giri (Collane, Vacanze, Ritiri…) servono a creare e pianificare
le tappe in agenda. Serve vedere **l'andamento dei ritiri**: per ogni scuola,
quali volumi restano da ritirare.

## Dati reali (account paolotax / "Production Tax", Propaganda 26)

| Giro | Tappe | Bolle | Note |
|---|---|---|---|
| Collane '26 | 122 | 183 | consegna principale (collana primaria 2026) |
| Vacanze '26 | 117 | 122 | seconda consegna, non tutte le scuole |
| Ritiri '26 | 122 | 1 | giro di ritiro: non crea bolle (solo quelle "al volo") |

Conseguenze sul modello:
- Il numero di giri **varia** (qui 3, "di solito 2"). Niente fasi fisse.
- Il giro di ritiro ha ~0 bolle → **colonne-per-giro inutili** per i ritiri.
- Il residuo da ritirare vive sulle **bolle** (con `collana_id`); ogni `CollanaLibro`
  ha `gruppo` ("Triennio 123", "Linguaggi 45", …) e `position` → ottimi per
  mostrare *cosa* è stato lasciato.
- Account team → una **Propaganda è di un utente** (i suoi giri, le sue bolle).

## Modello

- **`Propaganda`** (`app/models/propaganda.rb`, tabella `propagande`): `nome` libero,
  `user`, `account` (AccountScoped). `has_many :giri`. `Propaganda.corrente(user:)`
  = la più recente. Inflessione `propaganda/propagande` in `config/initializers/inflections.rb`.
- **`Giro`**: `belongs_to :propaganda, optional: true` (colonna `propaganda_id`).
- Bolle della propaganda = `BollaVisione` delle **tappe** dei giri della propaganda
  (`bolla → tappa → giro → propaganda`). Copre ~99% delle bolle.

## Andamento (per scuola × collana × gruppo)

`Propaganda#andamento(scuole)` → `[Propaganda::Scuola]`, ciascuno con `collane`
(`Propaganda::Collana`), ciascuna con `righe` (`Propaganda::Riga`) raggruppate per
`gruppo` e ordinate per `position`.

Value object in `app/models/propaganda/`:
- `Propaganda::Scuola` — `da_ritirare`, `mancanti`, `completata?`
- `Propaganda::Collana` — `totale`, `da_ritirare`, `rientrate`, `mancanti`,
  `completata?`, `gruppi`
- `Propaganda::Riga` — `da_ritirare?` (esito nil), `rientrata?`, `mancante?`

`da_ritirare` = righe con `esito` nil (lo scope `aperte`); `in_saggio` NON conta.

## UI

Pagina `propaganda#index` (route `GET /:account/propaganda`, `resources :propaganda`):
- Filtro province/area/ricerca riusato da `PropagandaFilter`.
- Una **card per scuola** (ambra se resta da ritirare, grigia se completata) con
  header "denominazione · N da ritirare".
- Per ogni collana un **`<details>`** (compatto + espandi): summary
  "collana — X/Y da ritirare" (ambra/grigio); espanso mostra i titoli raggruppati
  per `gruppo`, ciascuno con icona esito (☐ da ritirare, ✓ rientrato, ⚠ mancante)
  e quantità.
- Sostituisce la vecchia griglia scuole × giri (matrice tappe).

Stesso blocco riusato nella **scheda scuola** (`scuole/_container`).

## Setup / operatività

- Rake `propaganda:crea[user_id, nome, "giro_ids"]` crea la propaganda e le assegna i giri.
- Il **ritiro** resta dalla tappa del giorno (`scuola_ritiro_path`), con creazione
  bolla "al volo" quando ne manca una (caso reale: bolle dimenticate).

## Test

`test/models/propaganda_test.rb` (andamento, gruppi/ordinamento, mancanti, completata)
e `test/controllers/propaganda_controller_test.rb` (render pagina). Verdi.
