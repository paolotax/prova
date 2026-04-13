# Pianificabile — azione rapida "pianifica visita"

Data: 2026-04-13

## Obiettivo

Permettere di creare una `Tappa` (visita pianificata) con un click dalla scheda di una scuola, cliente, classe, persona, appunto o documento, scegliendo se andarci oggi, domani, o a una data specifica.

## Vincoli

- Filosofia "everything is CRUD": niente azioni custom su `TappeController`, si usa il `create` esistente.
- Convenzione naming dei concern: `-abile/-able` (Appuntabile, Entryable, Saldabile…).
- `Tappa.tappable` è polymorphic ma semanticamente ha senso solo su entità "visitabili" (hanno un indirizzo/posizione): Scuola, Cliente. Gli altri modelli sono "ponti" che risolvono il target.

## Concern `Pianificabile`

`app/models/concerns/pianificabile.rb`

```ruby
module Pianificabile
  extend ActiveSupport::Concern

  def tappa_target
    self
  end

  def default_titolo_tappa
    nil
  end
end
```

Un unico concern con default ragionevoli. I modelli "ponte" fanno override.

## Inclusioni

### Target diretti (`tappa_target = self`)

- **Scuola** — `include Pianificabile`
- **Cliente** — `include Pianificabile`

### Ponti (override)

- **Classe** → `tappa_target` = `scuola`; titolo `"Classe <sezione>"`
- **Persona** → `tappa_target` = `scuola` (può essere `nil`); titolo con nome/ruolo
- **Appunto** → `tappa_target` = `appuntabile`; titolo `"Appunto del <data>"`
- **Documento** → `tappa_target` = `clientable` (escluso `Domain::NessunCliente`); titolo `"<causale> <numero>"`

Se `tappa_target` è `nil`, il partial UI nasconde il bottone — niente errori runtime.

## UI — partial condiviso

`app/views/tappe/_pianifica.html.erb`

```erb
<%# locals: (source:) -%>
<% target = source.tappa_target %>
<% return unless target %>

<div class="btn-group">
  <% [["Oggi", Date.current], ["Domani", Date.tomorrow]].each do |label, date| %>
    <%= button_to label, tappe_path, method: :post, params: {
          tappa: {
            tappable_type: target.class.name,
            tappable_id:   target.id,
            data_tappa:    date,
            titolo:        source.default_titolo_tappa
          }
        }, class: "btn" %>
  <% end %>

  <%= link_to "Scegli giorno…", new_tappa_path(
        tappable_type: target.class.name,
        tappable_id:   target.id,
        source_titolo: source.default_titolo_tappa
      ), class: "btn" %>
</div>
```

- "Oggi"/"Domani" → `POST /tappe` standard, creazione immediata.
- "Scegli giorno…" → `GET /tappe/new` esistente, che già accetta `tappable_type`/`tappable_id`. Aggiungo la lettura di `params[:source_titolo]` per pre-compilare il titolo.

## Controller

Nessuna route nuova, nessun metodo nuovo. Solo una modifica minima a `TappeController#new` per leggere `source_titolo`:

```ruby
def new
  @tappable_type = params[:tappable_type] || "Scuola"
  @tappable_id   = params[:tappable_id]
  @data_tappa    = params[:data_tappa] || Date.today
  @tappa = current_user.tappe.build(
    tappable_id: @tappable_id,
    tappable_type: @tappable_type,
    data_tappa: @data_tappa,
    titolo: params[:source_titolo]
  )
end
```

## Montaggio nelle schede

- `app/views/appunti/container/_actions.html.erb` → sotto il bottone stampa esistente: `<%= render "tappe/pianifica", source: appunto %>`
- `app/views/documenti/container/_actions.html.erb` → idem con `source: documento`.
- Scuola/Cliente/Classe/Persona non hanno `container/_actions`: il partial va inserito in sidebar (es. sopra `scuole/container/_prossime_visite.html.erb`). Posizionamento esatto da decidere in fase di implementazione, pezzo per pezzo.

## Broadcasts

Nessun lavoro extra: `Tappa` include già `Entryable`, e `manage_entry_on_data_change` crea l'Entry associata quando `data_tappa <= today`. Il refresh globale avviene via `Entry::Broadcastable` esistente.

## Sicurezza

- `tappable_type`/`tappable_id` arrivano dal server (il partial li costruisce da `source.tappa_target`), non da input utente libero.
- `TappeController#create` usa `current_user.tappe.build` → scoping utente garantito.
- Il target è già visibile all'utente nella scheda da cui parte l'azione: nessun controllo aggiuntivo necessario.

## Non in scope

- Scelta del `giro` durante la pianificazione rapida (resta assegnabile nella edit).
- Descrizione libera (il partial imposta solo `titolo`).
- Supporto per pianificare tappe da liste/tabelle (solo dalle schede di dettaglio).
