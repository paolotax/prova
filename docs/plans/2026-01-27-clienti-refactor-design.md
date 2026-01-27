# Refactor Clienti CRUD - Design Document

**Data:** 2026-01-27
**Scope:** Refactor completo del CRUD Clienti seguendo pattern Fizzy (Appunti/Documenti)

## Obiettivo

Allineare Clienti al pattern Fizzy usato in Appunti e Documenti:
- Container pattern per show page
- Card arricchite con stats
- Form organizzato in fieldset
- CSS utilities Fizzy (panel, flex, gap, txt-*)

## Decisioni di Design

1. **Layout show**: 2 colonne (LEFT: dati + documenti, RIGHT: stats + actions)
2. **Card content**: Denominazione, tipo, contatti + stats (documenti count, fatturato)
3. **Info raggruppate**: 4 gruppi (Identificativi, Indirizzo, Contatti, Fatturazione)
4. **Pagination**: `with_automatic_pagination` (infinite scroll)

## Struttura File

```
app/views/clienti/
├── index.html.erb
├── show.html.erb
├── new.html.erb
├── edit.html.erb
├── _cliente.html.erb
├── _form.html.erb
├── container/
│   ├── _container.html.erb
│   ├── _details.html.erb
│   ├── _stats.html.erb
│   ├── _documenti.html.erb
│   ├── _actions.html.erb
│   └── _sconti.html.erb
└── display/
    └── _meta.html.erb
```

## Controller Modifiche

```ruby
# clienti_controller.rb
def index
  @clienti = @filter.clienti.order(denominazione: :asc)
  @total_count = @clienti.count
  set_page_and_extract_portion_from @clienti
end

def show
  @documenti_recenti = @cliente.documenti.order(data_documento: :desc).limit(5)
end
```

## Helper

```ruby
# clienti_helper.rb
module ClientiHelper
  def cliente_color(cliente)
    case cliente.tipo_cliente
    when "Libreria"      then "oklch(0.6 0.15 250)"
    when "Cartolibreria" then "oklch(0.6 0.15 160)"
    when "Edicola"       then "oklch(0.6 0.15 45)"
    else "oklch(0.6 0.01 0)"
    end
  end
end
```

## Card Layout

```erb
<article class="card" style="--card-color: #{cliente_color(cliente)}">
  <header class="card__header">
    <div class="card__board">
      <span class="card__id">TIPO</span>
      <span class="card__board-name">Comune, Provincia</span>
    </div>
  </header>
  <div class="card__body">
    <h3 class="card__title">Denominazione</h3>
    <div class="card__stages">Telefono, Email</div>
  </div>
  <footer class="card__footer">
    <div class="card__meta">P.IVA, Doc count, Fatturato</div>
  </footer>
</article>
```

## Show Layout (2 colonne)

```erb
<div class="flex gap" style="--column-gap: var(--block-space-double);">
  <div class="flex flex-column gap flex-1" style="flex-basis: 600px;">
    <!-- Details: 4 panel separati -->
    <!-- Documenti recenti -->
  </div>
  <aside style="flex-basis: 280px;">
    <!-- Stats -->
    <!-- Quick Actions -->
  </aside>
</div>
```

## Form (Fieldset)

Il form è organizzato in 4 fieldset:
1. **Dati Identificativi**: P.IVA, CF, Codice, Tipo
2. **Indirizzo**: Via, CAP, Comune, Provincia
3. **Contatti**: Telefono, Email, PEC
4. **Fatturazione**: SDI, Condizioni, Metodo, Banca

## Hotkeys

- `Insert` su index → Nuovo cliente
- `E` su show → Modifica
- `Left/Esc` → Torna indietro

## Verifiche

1. `/clienti` - grid con card e pagination infinite scroll
2. Click cliente - show con 2 colonne
3. Hotkey `Insert` - nuovo cliente
4. Hotkey `E` su show - edit
5. Form con fieldset separati
6. Responsive mobile

## Prossimi Passi (dopo Clienti)

1. **Libri** - stesso pattern
2. **Scuole** - stesso pattern
