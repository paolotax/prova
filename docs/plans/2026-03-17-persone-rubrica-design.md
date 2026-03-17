# Persone — Rubrica Globale e Unificazione Partial

**Data:** 2026-03-17
**Obiettivo:** Creare un index globale delle persone (rubrica contatti) e unificare i partial di visualizzazione, spostando il CRUD completo nel controller top-level `PersoneController`.

## Decisioni di Design

- CRUD completo in `PersoneController` (top-level, `/persone`)
- Partial in `app/views/persone/` — unica fonte per tutte le viste
- Show identica a quella attuale, URL `/persone/:id` invece di `/scuole/:scuola_id/persone/:id`
- Se la persona ha una scuola, mostra comunque classi/adozioni/materie
- Index con cards in lista, stile coerente con scuole/libri
- Filtri e ordinamenti come fase successiva

## 1. Routes

```ruby
# Top-level — CRUD completo
resources :persone, only: [:index, :show, :edit, :update, :create, :destroy] do
  resources :persona_classi, only: [:destroy], module: :persone
  resources :classe_chips, only: [:create], module: :persone, param: :combobox_value
  resources :saggi, only: [:create, :update, :destroy], module: :persone
end

# Sotto scuola — contesto specifico (search, import, create rapido)
resources :scuole do
  resources :persone_search, only: [:index]
  resource :persone_import, only: [:new, :create]
  resources :persone, only: [:show, :create]  # show redirect, create per aggiunta rapida
  resources :classi do
    resources :persone, only: [:new, :create, :destroy], module: :classi
  end
end
```

## 2. Spostamento Partial

I partial migrano da `app/views/scuole/persone/` a `app/views/persone/`.

### Struttura finale

```
app/views/persone/
  index.html.erb                    # NUOVO — lista cards
  show.html.erb                     # da scuole/persone/show
  _persona.html.erb                 # NUOVO — card per collection rendering
  _container.html.erb               # da scuole/persone/_container
  _content_display.html.erb         # da scuole/persone/_content_display
  _edit_form.html.erb               # da scuole/persone/_edit_form
  _search_dialog.html.erb           # da scuole/persone/_search_dialog
  _footer.html.erb
  _edit_footer.html.erb
  display/perma/_board.html.erb
  container/
    _appunti.html.erb
    _saggi.html.erb
  create.turbo_stream.erb
  edit.turbo_stream.erb
  show.turbo_stream.erb
```

### Eliminare

```
app/views/scuole/persone/           # Tutto tranne eventuale create.turbo_stream.erb
```

## 3. Controller

### PersoneController (top-level) — CRUD completo

```ruby
class PersoneController < ApplicationController
  def index
    @persone = current_account.persone
                               .includes(:scuola, :classi)
                               .order(:cognome, :nome)
    @pagy, @persone = pagy(@persone)
  end

  def show
    @persona = current_account.persone.find(params[:id])
    # Logica prev/next, appunti, saggi (da Scuole::PersoneController)
  end

  def edit / update / create / destroy
    # Logica esistente da Scuole::PersoneController
  end
end
```

### Scuole::PersoneController — ridotto

```ruby
class Scuole::PersoneController < ApplicationController
  def show
    redirect_to persona_path(params[:id])
  end

  def create
    # Create rapido da contesto scuola, assegna scuola_id automaticamente
  end
end
```

## 4. Index — Card Persona

Ogni card mostra:
- Nome completo (cognome + nome)
- Ruolo (badge: docente, dirigente, segretario, referente)
- Scuola (link, se presente)
- Contatti: icone telefono/email se presenti
- Numero classi (se docente)

Ordinamento default: cognome, nome.

## 5. Aggiornamento Link

Tutti i link nelle viste scuola cambiano:
- `scuola_persona_path(@scuola, persona)` → `persona_path(persona)`
- `_insegnanti.html.erb`, `_docenti.html.erb` e altri

## 6. Search Dialog

Il `_search_dialog.html.erb` si sposta in `persone/` ma il form action per il create rapido da scuola viene passato come local variable.

## 7. Breadcrumb

- Da rubrica: `Persone > Mario Rossi`
- La scuola appare come link nel contenuto, non nel breadcrumb

## Fase Successiva (non in scope)

- `Filters::PersonaFilter` con `FilterScoped`
- Filtro per ruolo, scuola, ricerca nome
- Ordinamenti personalizzati
