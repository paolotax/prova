# Propaganda — Tabella riepilogativa giri

**Data:** 2026-03-22

## Obiettivo

Pagina dedicata che mostra in formato spreadsheet la situazione di tutti i giri aperti, con tutte le scuole dell'utente come righe e i giri come colonne.

## Struttura

### Rotta e controller

- `GET /propaganda` → `PropagandaController#index`
- Controller dedicato, non annidato sotto giri

### Layout tabella

| Provincia | Area | Scuola | Giro 1 | Giro 2 | ... |
|-----------|------|--------|--------|--------|-----|
| MI | 2 | Plesso Rossi | `cella` | | |
| TO | 1 | Plesso Verdi | | `cella` | |

- **Righe:** tutte le scuole dell'utente (Current.account), ordinate per provincia, area, nome. Solo plessi (no direzioni pure)
- **Colonne fisse:** Provincia, Area, Scuola
- **Colonne dinamiche:** una per ogni giro selezionato

### Filtro giri

- Selettore multi-select in alto
- Default: tutti i giri aperti (`finito_il IS NULL`)
- Possibilità di aggiungere giri chiusi
- Submit con Turbo Frame per aggiornare solo la tabella

### Cella tappa

Quando la scuola ha una tappa nel giro:

**Sfondo colorato per stato** (stessi colori timeline/tappa_color):
- Completata → grigio `oklch(0.6 0.01 0)`
- Rimandata → grigio chiaro
- Oggi → verde `oklch(0.6 0.15 160)`
- Domani → giallo `oklch(0.7 0.15 85)`
- Programmata futura → rosa `oklch(0.6 0.15 350)`
- Da programmare (senza data) → rosa scuro
- Passata non completata → grigio

**Contenuto testo:**
- Riga 1: data (giorno + mese abbreviato), omessa se da programmare
- Riga 2: N bolle · N libri (omessa se zero)
- Riga 3: nota troncata (~30 char, solo se presente)

**Cella vuota:** niente, bianca. Spazio per azioni future.

## Query

```ruby
# Scuole — tutte, ordinate
@scuole = Current.account.scuole
  .where.not(id: Current.account.scuole.where.not(direzione_id: nil).select(:direzione_id).distinct)
  .order(:provincia, :area, :nome)
  # oppure filtrare solo plessi con logica appropriata

# Giri — aperti di default, filtrabili
@giri = current_user.giri.where(finito_il: nil)
@giri = current_user.giri.where(id: params[:giro_ids]) if params[:giro_ids].present?

# Tappe con eager loading
tappe = Tappa.where(tappable_type: "Scuola", tappable_id: @scuole.ids)
  .joins(:tappa_giri).where(tappa_giri: { giro_id: @giri.ids })
  .includes(:entry, :bolle_visione, bolle_visione: :bolla_visione_righe)

# Hash per lookup O(1)
@tappe_map = {}
tappe.each do |tappa|
  tappa.tappa_giri.each do |tg|
    @tappe_map[[tappa.tappable_id, tg.giro_id]] = tappa
  end
end
```

## File

```
config/routes.rb                          # resource :propaganda, only: [:index]
app/controllers/propaganda_controller.rb  # index action
app/views/propaganda/index.html.erb       # tabella con filtro
app/views/propaganda/_cella.html.erb      # partial cella giro
```

## Note tecniche

- Una tappa può appartenere a più giri (via TappaGiro) → può comparire in più colonne
- Helper `tappa_color` già esiste in `TappeHelper`
- Niente Turbo Frame per singole celle — tabella come blocco unico
- Niente JavaScript dedicato — tabella statica, scrollabile orizzontalmente
- CSS del progetto (classi Fizzy), no Tailwind
