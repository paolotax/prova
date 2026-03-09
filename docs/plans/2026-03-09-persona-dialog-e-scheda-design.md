# Design: Dialog Persona e Scheda Docente

## Problema

- Insegnanti inseriti doppi, in scuole sbagliate
- Popup ricerca/inserimento persona fatti male in diversi punti
- Validazione sbagliata (solo cognome obbligatorio, ma nelle elementari spesso si sa solo il nome)
- Email istituzionali seguono pattern prevedibili ma non vengono generate
- Un insegnante puo insegnare in piu scuole (vicario in una, docente in altra)
- `scuola_id` su persona e `belongs_to :scuola` — limita a una sola scuola

## Decisioni architetturali

### Persona multi-scuola (approccio incrementale)

- `scuola_id` resta come **scuola principale** (in futuro sara l'istituto comprensivo)
- La persona appare in ogni scuola dove ha `persona_classi`
- Nella scheda persona le classi si raggruppano per scuola
- Dalla scheda si possono aggiungere classi di altre scuole
- **Nessuna migration necessaria** — solo query e viste

### Validazione persona

- Almeno **cognome o nome** obbligatorio (non entrambi)
- Questo copre il caso elementari dove si sa solo il nome

---

## Dialog Ricerca/Inserimento Persona

Usata in: scuola show, classe, bolla visione. Stessa dialog ovunque.

### Combobox di ricerca (hotwire_combobox)

- Cerca per **nome o cognome** (match parziale)
- Risultati raggruppati:
  - **Prima**: persone della scuola corrente
  - **Poi**: persone di altre scuole (con nome scuola visibile)
- Ogni risultato mostra: nome completo, materia, scuola (se diversa)
- Se non trova: appare **tasto "Aggiungi"** che copia il testo nel form

### Form nuovo persona

Appare dopo click su "Aggiungi":

- **Cognome** e **nome** (almeno uno obbligatorio)
- **Materia** con autocomplete dai valori esistenti nella scuola (campo libero, no tabella cattedre per elementari)
- **Email** pre-compilata dal pattern della direzione (suggerita, modificabile)
- Al salvataggio: crea persona con `scuola_id` corrente, assegna a tutte le classi della scuola con quella materia

### Selezione persona esistente

- Se la persona e della **stessa scuola** → apre la scheda
- Se e di **un'altra scuola** → dialog conferma "Trasferire da [scuola X]?" → aggiorna `scuola_id`

---

## Pattern Email Direzioni

### Campo sulla direzione

- Nuovo campo `email_pattern` su `Direzione` (es. `{nome}.{cognome}@iceinstein-re.edu.it`)
- Placeholder con variabili: `{nome}`, `{cognome}`

### Generazione email

- Quando si crea una persona, l'email viene **suggerita** dal pattern della direzione della scuola
- L'utente puo modificarla prima di salvare
- Generazione: lowercase, rimuovi accenti, sostituisci spazi

---

## Scheda Persona (show) — Da ricostruire

### Header

- Nome completo, ruolo (chip), scuola principale
- Navigazione prev/next persona
- Bottone modifica (hotkey E)

### Classi raggruppate per scuola

- Per ogni scuola: nome scuola, badge classi con colori adozioni
- Bottone per aggiungere classi (combobox con classi di qualsiasi scuola dell'account)
- Libri adottati per anno sotto ogni gruppo scuola

### Contatti

- Cellulare, telefono, email
- Bottone "Genera email" se vuoto e pattern disponibile

### Saggi e Appunti

- Come adesso, form inline

---

## Lista insegnanti nella scuola show

### Query aggiornata

```ruby
# Mostra persone con scuola_id qui + persone con classi qui
persone = Persona.where(ruolo: [:docente, :referente])
  .where(id: scuola.persone.select(:id))
  .or(Persona.where(id: PersonaClasse.where(classe_id: scuola.classi.select(:id)).select(:persona_id)))
  .includes(persona_classi: :classe)
  .order(Arel.sql("posizione IS NULL, posizione, cognome, nome"))
```

### Recapiti sotto il nome

- Se la persona ha cellulare/telefono/email, mostra sotto il nome in `txt-xx-small txt-subtle`

### Referenti senza materia

- Gruppo separato "Referenti" in fondo alla lista
- Mostra ruolo come chip

---

## File coinvolti

- `app/views/scuole/container/_insegnanti.html.erb` — lista con referenti e recapiti
- `app/views/scuole/persone/_edit_form.html.erb` — form edit con scuola combobox e ruolo
- `app/controllers/scuole/persone_controller.rb` — update con cambio scuola, prev/next con referenti
- `app/models/persona.rb` — validazione cognome OR nome
- `app/models/direzione.rb` — campo `email_pattern`
- `db/migrate/` — add `email_pattern` to `direzioni`
- Dialog condivisa da creare come partial riusabile
