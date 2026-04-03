# Email istruzioni installazione Scagnozz CLI

## Obiettivo

Creare un mailer per inviare istruzioni di installazione e configurazione di Scagnozz CLI agli utenti selezionati dall'admin panel.

## Pattern

Replica esatta del pattern ExtensionMailer:
- `CliMailer` con metodo `send_instructions(user)`
- `Admin::CliMailsController` con index (selezione utenti) e create (invio bulk)
- Template email con componenti `Email::*`
- Route `admin/cli_mails`

## Contenuto della mail

### Oggetto
"Scagnozz CLI — il tuo assistente AI per adozioni, ordini e contatti"

### Struttura

1. **Intro** — cos'è e perché serve (3 righe)
2. **Cosa può fare** — lista funzionalità (adozioni prima)
3. **Installazione** — passo-passo Mac/Linux + Windows
4. **Primo setup** — `scagnozz setup`
5. **Configurazione MCP** — `scagnozz mcp install` + `scagnozz skill install`
6. **Box aggiornamento** — per chi ha già il CLI

### Tono
Informale, "tu", zero gergo tecnico, istruzioni numerate.

## File da creare

1. `app/mailers/cli_mailer.rb`
2. `app/controllers/admin/cli_mails_controller.rb`
3. `app/views/cli_mailer/send_instructions.html.erb`
4. `app/views/admin/cli_mails/index.html.erb`
5. Route in `config/routes.rb`

## Decisioni

- Selezione manuale utenti dall'admin (come ExtensionMailer)
- Livello "zero tecnico" nelle istruzioni
- Client supportati: Claude Desktop, Claude Code, OpenCode
- Installazione: `curl | bash` per Mac/Linux, download exe per Windows
- Configurazione MCP: `scagnozz mcp install` (menu interattivo)
- Skill: `scagnozz skill install`
