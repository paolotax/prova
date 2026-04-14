# Tappa dedup — evitare duplicati pianificando da API/UI

Data: 2026-04-14

## Contesto

Bug report (13 aprile): quando Claude via MCP `tappa_create` pianifica una scuola in un
giro, la tappa "da programmare" esistente per la stessa scuola nello stesso giro resta viva
→ duplicato visibile sia tra le programmate che tra le da pianificare.

## Regola concordata

1. **Upsert automatico (solo API)**: se si crea una tappa con `giro_id` + `data_tappa`,
   e per lo stesso `user + tappable + giro` esiste già una tappa con `data_tappa: nil`
   → aggiornare quella invece di crearne una nuova. Aggiornare anche `titolo` se passato.
2. **Tappe future**: non toccarle mai automaticamente. Sono pianificazioni esplicite.
3. **Segnalazione UI**: nel partial `tappe/_pianifica.html.erb`, mostrare a fianco dei
   bottoni le tappe **future** per lo stesso tappable con data + giro, come info read-only.
4. **Controller HTML**: non cambia nulla. Il flusso "Oggi/Domani" da scheda parte da un
   target che non è ancora in nessun giro, quindi non c'è rischio del bug.

## Task 1 — `Tappa.schedule_in_giro!`

**Files:**
- Modify: `app/models/tappa.rb`
- Test: `test/models/tappa_test.rb`

Metodo classe:

```ruby
def self.schedule_in_giro!(user:, tappable:, giro:, data_tappa:, titolo: nil)
  existing = user.tappe
    .where(tappable: tappable, data_tappa: nil)
    .joins(:tappa_giri).where(tappa_giri: { giro_id: giro.id })
    .first

  if existing
    existing.update!(data_tappa: data_tappa, titolo: titolo.presence || existing.titolo)
    existing
  else
    tappa = user.tappe.create!(
      tappable: tappable,
      data_tappa: data_tappa,
      titolo: titolo
    )
    tappa.tappa_giri.create!(giro: giro)
    tappa
  end
end
```

**Test cases (TDD):**
1. Nessuna tappa esistente → crea nuova tappa + tappa_giro, ritorna nuova tappa.
2. Tappa `data_tappa: nil` nello stesso giro → aggiorna quella, nessuna nuova creata.
3. Tappa `data_tappa: nil` in **altro** giro → crea nuova (non tocca l'altra).
4. Tappa **futura** nello stesso giro → crea nuova (non tocca la futura).
5. `titolo: nil` con tappa esistente che ha già titolo → preserva il titolo esistente.

## Task 2 — `MCPTools::TappaCreate` usa il metodo

**Files:**
- Modify: `app/tools/mcp_tools/tappa_create.rb`

Logica:

```ruby
if giro_id.present? && data_tappa.present?
  giro = Current.user.giri.find(giro_id)
  klass, id = Appuntabile.parse_appuntabile_value(tappable_value)
  tappable = klass.find(id)
  tappa = Tappa.schedule_in_giro!(
    user: Current.user, tappable: tappable, giro: giro,
    data_tappa: Date.parse(data_tappa), titolo: titolo
  )
  # response
else
  # comportamento attuale (niente giro o niente data)
end
```

**Test:** non aggiungo test MCP (non ce ne sono già) — copertura arriva dal test del
modello.

## Task 3 — Partial `tappe/_pianifica.html.erb` mostra tappe future

**Files:**
- Modify: `app/views/tappe/_pianifica.html.erb`

Sopra la lista `popup__list`, aggiungere un blocco che mostra le tappe future del
tappable (solo se ce ne sono):

```erb
<% future = Current.user.tappe
     .where(tappable: target)
     .where("data_tappa >= ?", Date.current)
     .includes(:giri)
     .order(:data_tappa) %>
<% if future.any? %>
  <li class="popup__item popup__item--info">
    <div class="txt-small fg-muted padding-inline-3 padding-block-2">
      Già pianificata:
      <% future.each do |t| %>
        <div>
          <%= l(t.data_tappa, format: :short) %>
          <% if t.giri.any? %> — <%= t.giri.map(&:titolo).join(", ") %><% end %>
        </div>
      <% end %>
    </div>
  </li>
<% end %>
```

Solo informativo. Niente link, niente azioni. L'utente decide cosa fare.

**Nota:** uso `Current.user.tappe.where(tappable: target)` invece di `target.tappe`
perché `Cliente.has_many :tappe` ha uno scope con `Current.user.id` mentre `Scuola.has_many :tappe`
non lo ha — la via via `Current.user.tappe` è uniforme.

## Non in scope

- Rimpiazzare `TappeController#create` con upsert: il flusso UI da scheda non genera
  il bug (parte da target senza tappa esistente nel giro).
- Endpoint MCP separato `tappa_schedule`: fixare `tappa_create` è sufficiente.
- Deduplicazione delle tappe già esistenti in DB (cleanup storico).
