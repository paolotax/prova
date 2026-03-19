# Email Pattern Docenti — Design

## Obiettivo

Generare automaticamente l'indirizzo email dei docenti basandosi sul pattern email della direzione (istituto comprensivo). Ogni direzione ha un proprio dominio e formato per le email dei suoi insegnanti.

## Pattern supportati

| Chiave | Formato | Esempio |
|--------|---------|---------|
| `nome.cognome` | nome.cognome@dominio | mario.rossi@ickennedy.istruzione.it |
| `n.cognome` | n.cognome@dominio | m.rossi@icdavinci.edu.it |
| `cognome.nome` | cognome.nome@dominio | rossi.mario@icmanzoni.edu.it |
| `nomecognome` | nomecognome@dominio | mariorossi@ickennedy.istruzione.it |
| `cognomenome` | cognomenome@dominio | rossimario@icdavinci.edu.it |

Possibilità di aggiungere pattern custom tramite opzione "Altro..." nel dropdown.

## Migrazione

Aggiungere alla tabella `scuole`:
- `email_pattern` (string) — chiave del pattern o template custom
- `email_dominio` (string) — dominio email (es. `ickennedy.istruzione.it`)

## Modello Scuola

Costante `EMAIL_PATTERNS` con i 5 pattern predefiniti.

Metodo `genera_email_docente(nome, cognome)`:
- Combina pattern + dominio per generare l'email
- Il plesso delega alla direzione: `(direzione || self).genera_email_docente(nome, cognome)`
- Gestisce normalizzazione (lowercase, rimozione accenti/spazi)

## UI — Form Scuola (sezione "Email docenti")

Due campi affiancati:
- **Select "Formato"** — dropdown con i 5 pattern + opzione "Altro..." che mostra un campo testo per pattern custom
- **Campo testo "Dominio"** — es. `ickennedy.istruzione.it`

**Preview live** sotto i campi: mostra un esempio generato (es. "mario.rossi@ickennedy.istruzione.it") che si aggiorna in tempo reale.

Stimulus controller `email-pattern` per gestire il preview e il toggle del campo custom.

## UI — Form Persona

Quando l'utente compila nome e cognome:
- Se la scuola (o la sua direzione) ha pattern e dominio configurati, il campo email si popola automaticamente
- Il campo resta editabile — l'utente può correggere o sovrascrivere
- Non sovrascrive se l'utente ha editato manualmente

Pattern e dominio passati come **data attributes** nel form (nessuna chiamata server).

Stimulus controller `email-suggest`:
- Ascolta `input` su nome e cognome
- Genera l'email lato client
- Popola il campo email (solo se non modificato manualmente)

## Test

- Test del metodo `genera_email_docente` sul modello Scuola (unica logica server-side da testare)
