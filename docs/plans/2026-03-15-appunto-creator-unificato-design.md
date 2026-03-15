# Appunti::AppuntoCreator — API unificata creazione appunto

## Problema

Ci sono 4 percorsi diversi per creare un appunto (web form, mobile form, API, WhatsApp) con logica duplicata e comportamenti incoerenti: parametri diversi, creazione persona diversa, stato iniziale diverso (draft vs published).

## Soluzione

Un PORO `Appunti::AppuntoCreator` che gestisce tutto il workflow di creazione. I controller diventano sottili e delegano al creator.

## Decisioni

- **Drafted ovunque** — ogni chiamata crea un nuovo appunto drafted. Il chiamante passa `publish: true` per pubblicare subito (es. WhatsApp)
- **Più bozze possibili** — niente più `find_or_initialize_by`. Le bozze si accumulano nel tray, l'utente le rivede e pubblica o elimina
- **Appuntabile: Scuola/Cliente di default, Persona fallback** — se il creator ha una persona ma nessun appuntabile esplicito, risale alla scuola della persona; se non ha scuola, usa la persona
- **Persona find-or-create** — da WhatsApp per cellulare, da form con nome o cognome. Collegabile a scuola
- **Pattern PORO Fizzy** — `ActiveModel::Model` in `app/models/appunti/`, niente service object

## Parametri uniformi

```
appunto[nome]              # titolo/destinatario
appunto[content]           # testo
appunto[appuntabile_value] # "Scuola:uuid", "Cliente:id", "Classe:uuid", "Persona:uuid"
appunto[telefono]          # telefono contatto
appunto[email]             # email contatto
appunto[attachments][]     # file allegati

persona[nome]              # per creare/trovare persona
persona[cognome]           # opzionale (basta uno tra nome e cognome)
persona[cellulare]         # per find-or-create da WhatsApp
persona[email]             # opzionale
persona[scuola_nome]       # per collegare persona a scuola

publish                    # true per pubblicare subito (WhatsApp)
```

## PORO

```ruby
# app/models/appunti/appunto_creator.rb
class Appunti::AppuntoCreator
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :nome
  attribute :content
  attribute :appuntabile_value
  attribute :telefono
  attribute :email
  attribute :publish, :boolean, default: false

  attribute :persona_nome
  attribute :persona_cognome
  attribute :persona_cellulare
  attribute :persona_email
  attribute :persona_scuola_nome

  attr_reader :appunto, :persona

  def create
    find_or_build_persona
    resolve_appuntabile
    build_appunto
    appunto.save && maybe_publish
    appunto
  end

  private

  def find_or_build_persona
    return unless persona_cellulare.present? || persona_nome.present? || persona_cognome.present?

    if persona_cellulare.present?
      @persona = Current.account.persone.find_by(cellulare: persona_cellulare) ||
                 Current.account.persone.find_by(telefono: persona_cellulare)
    end

    @persona ||= Current.account.persone.build(
      nome: persona_nome,
      cognome: persona_cognome,
      cellulare: persona_cellulare,
      email: persona_email
    )

    if persona_scuola_nome.present? && @persona.scuola.blank?
      scuola = Current.account.scuole.find_by_nome(persona_scuola_nome)
      # collegamento persona-scuola se trovata
    end

    @persona.save! if @persona.new_record?
  end

  def resolve_appuntabile
    if appuntabile_value.present?
      @resolved_appuntabile = Appuntabile.parse_appuntabile_value(appuntabile_value)
    elsif @persona&.scuola.present?
      @resolved_appuntabile = @persona.scuola
    elsif @persona.present?
      @resolved_appuntabile = @persona
    end
  end

  def build_appunto
    @appunto = Current.account.appunti.build(
      user: Current.user,
      nome: nome,
      content: content,
      telefono: telefono,
      email: email,
      appuntabile: @resolved_appuntabile
    )
  end

  def maybe_publish
    appunto.publish if publish && appunto.persisted?
  end
end
```

## Flusso

```
Qualsiasi canale
    │
    ▼
Appunti::AppuntoCreator.new(params)
    │
    ├─ find_or_build_persona (se cellulare o nome/cognome presenti)
    │   └─ collega a scuola se persona_scuola_nome fornito
    │
    ├─ resolve_appuntabile (priorità):
    │   1. appuntabile_value esplicito (Scuola/Cliente/Classe/Persona)
    │   2. scuola della persona
    │   3. persona come fallback
    │   4. nil (da completare dopo)
    │
    ├─ build_appunto (sempre nuovo, drafted)
    │
    └─ publish se publish: true

    ▼
Appunto drafted → tray bozze → utente rivede e pubblica
```

## Controller dopo refactor

```ruby
# AppuntiController#create (web form)
creator = Appunti::AppuntoCreator.new(creator_params)
creator.create
redirect_to creator.appunto

# Mobile::AppuntiController#create
creator = Appunti::AppuntoCreator.new(creator_params)
creator.create
redirect_to new_mobile_appunto_path

# Api::V1::AppuntiController#create
creator = Appunti::AppuntoCreator.new(creator_params)
creator.create
render json: { success: true, appunto_id: creator.appunto.id }

# Api::WhatsappController#create
creator = Appunti::AppuntoCreator.new(
  persona_cellulare: params[:telefono],
  persona_nome: params[:nome],
  persona_scuola_nome: params[:scuola_nome],
  content: params[:messaggio],
  publish: true
)
creator.create
render json: { appunto_id: creator.appunto.id, persona_id: creator.persona&.id }
```

## Da eliminare

- `User#draft_new_appunto` — sostituito dal creator che crea sempre un nuovo record
- Logica duplicata di creazione persona nei singoli controller

## Da modificare

| File | Modifica |
|------|----------|
| `app/controllers/appunti_controller.rb` | `new`/`create` delegano al creator |
| `app/controllers/mobile/appunti_controller.rb` | `create` delega al creator |
| `app/controllers/api/v1/appunti_controller.rb` | `create` delega al creator |
| `app/controllers/api/whatsapp_controller.rb` | `create` delega al creator, mappa parametri legacy |
| `app/models/user.rb` | Rimuovere `draft_new_appunto` |

## Da creare

| File | Scopo |
|------|-------|
| `app/models/appunti/appunto_creator.rb` | PORO con logica unificata |
| `test/models/appunti/appunto_creator_test.rb` | Test del creator |
