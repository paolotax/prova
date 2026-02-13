# Design: Dashboard Adozioni Analytics + Import Insegnanti PDF

Data: 2026-02-13
Deadline: martedi 2026-02-18
Target: colleghi (member dell'account)

## Feature 1: Dashboard Adozioni Analytics

### Requisiti

- Ogni member vede dati filtrati per le proprie scuole (MembershipScuola), admin/owner vede tutto
- Dati da `import_adozioni` (ministeriali, nazionali, cambiano 1/anno) per confronti
- Dati da `adozioni` (account-scoped, flag `mia`) per le proprie
- Metriche: numero sezioni, copie stimate (sezioni x 18), % su totale
- UI: pagina unica con 4 tab

### Architettura

**Controller:** `AdozioniAnalyticsController#index`
**Route:** `resource :adozioni_analytics, only: [:index]`
**PORO:** `AdozioniAnalytics` per le query aggregate

### Tab

| Tab | Fonte | Scope | Raggruppamento |
|-----|-------|-------|----------------|
| Le mie | Adozione (mia: true, disdetta: false) | Scuole del member | disciplina > titolo > classi |
| Agenzia | Adozione (mia: true) | Tutte scuole account | disciplina > titolo > classi |
| Confronto editori | import_adozioni | Scuole account (via codice_ministeriale) | editore > disciplina > titolo |
| Provincia/Nazionale | import_adozioni | Provincia intera / Tutto | editore > disciplina > classe |

### Filtri

Disciplina, anno_corso (1/2/3), editore. Via query params, Turbo Frame per aggiornamento parziale.

### File

- `app/controllers/adozioni_analytics_controller.rb`
- `app/models/adozioni_analytics.rb` (PORO, no ActiveRecord)
- `app/views/adozioni_analytics/index.html.erb`
- `app/views/adozioni_analytics/_tab_mie.html.erb`
- `app/views/adozioni_analytics/_tab_agenzia.html.erb`
- `app/views/adozioni_analytics/_tab_confronto.html.erb`
- `app/views/adozioni_analytics/_tab_dati.html.erb`

---

## Feature 2: Import Insegnanti da PDF ANARPE

### Requisiti

- Upload PDF formato ANARPE dalla pagina scuola
- Parse header (pag 1): codice ministeriale, dirigente, vice, dir. amm., resp. biblioteca
- Parse schede insegnanti (pag 2+): cognome, nome, materia, classi
- Collegamento insegnante <> classi con materia

### Formato PDF ANARPE

**Pagina 1 - Header scuola:**
- Codice ministeriale, denominazione, indirizzo
- Dirigente, Vice, Dir. amministrativo, Resp. biblioteca
- Sezioni per anno con conteggio classi e alunni

**Pagine 2+ - Schede insegnanti:**
- COGNOME NOME (bold)
- MATERIA (es. LETTERE, MATEMATICA E SCIENZE)
- Classi in formato compatto: `12AG 1EH -`

### Parsing classi compatto

- Split per spazi, ignora `-`
- Cifre iniziali = anni_corso, lettere successive = sezioni
- `12AG` -> anni [1,2] x sezioni [A,G] -> 1A, 2A, 1G, 2G
- `1EH` -> anno [1] x sezioni [E,H] -> 1E, 1H

### Modello dati

Nuovo join model:

```
persona_classi (UUID)
  persona_id: uuid (required)
  classe_id: uuid (required)
  materia: string
  unique: (persona_id, classe_id)
```

Modello `Persona` esiste gia con: cognome, nome, ruolo (enum), scuola_id, account_id.

### Flow

1. Scuola show -> bottone "Importa insegnanti (PDF)"
2. Dialog con file upload
3. `PersoneController#import_pdf` -> `AnarpeImporter.call(file, scuola)`
4. Parse PDF -> crea Persona (ruolo: docente) + PersonaClasse
5. Redirect con flash
6. Sezione "Insegnanti" nella pagina scuola

### File

- `app/services/anarpe_importer.rb` (parser + import)
- `app/models/persona_classe.rb` (join model)
- `db/migrate/..._create_persona_classi.rb`
- `app/views/scuole/container/_insegnanti.html.erb`
- `app/controllers/persone_controller.rb` (action import_pdf)
- Gem: `pdf-reader`
