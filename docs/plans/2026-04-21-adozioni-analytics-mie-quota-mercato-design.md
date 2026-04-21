# Adozioni Analytics "Le mie" — Quota di mercato e confronto nazionale

**Data**: 2026-04-21
**Branch**: `feature/multi-tenancy`
**Scope**: `AdozioniAnalyticsController#show`, tab "Le mie"

## Obiettivo

Migliorare la tab "Le mie" di `/adozioni_analytics`:

1. Calcolare la percentuale di ogni adozione come **quota di mercato reale** dentro il suo (disciplina, anno_corso), non come semplice frazione del totale complessivo.
2. Affiancare nella stessa tabella il **confronto col mercato nazionale** per stesso grado + tipo_scuola + disciplina + anno_corso + ISBN.
3. Nascondere (non eliminare) i tab **Agenzia**, **Confronto editori**, **Provincia/Nazionale**.

## Decisioni di design

### Interpretazione "quota di mercato"

Per un libro X adottato in una classe di anno_corso A per disciplina D:

```
quota_mia = sezioni_tracciate(X in D, A) / totale_sezioni_in_zona_per_(D, A)
```

Il **numeratore** è `row.sezioni_count` dal model `Adozione.mie` (= classi tracciate dove io adotto il libro X).

Il **denominatore** è la totalità delle sezioni nel mercato `(tipo_scuola, disciplina, anno_corso)` **nella zona** dell'utente — calcolato su `import_adozioni` filtrato per `CODICESCUOLA ∈ codici_ministeriali` delle scuole dell'utente.

Questo rende "Mia %" una vera quota di mercato (non una frazione del portfolio tracciato): se io tracco solo i libri Giunti in un mercato dove esistono anche Zanichelli/Mondadori, la mia quota *non* è 100% ma la percentuale reale che i miei libri coprono. Le percentuali in una tabella *non* sommano a 100% se non traccio tutti gli editori.

### Interpretazione "confronto nazionale"

Il match tra un libro "mio" e il dato nazionale avviene su 5 chiavi:

```
(grado, tipo_scuola, disciplina, anno_corso, codice_isbn)
```

Sia grado che tipo_scuola sono richiesti — senza di loro il denominatore sarebbe gonfiato da mercati eterogenei (es. "italiano 1ª" potrebbe includere elementare + media + superiori).

Per ogni riga mia calcolo:
- `naz_% = sezioni_naz(libro) / totale_sezioni_naz(mercato)`
- `delta = mia_% − naz_%` (in punti percentuali)

### Granularità riga

Una riga per ogni `(grado, tipo_scuola, anno_corso, disciplina, titolo, editore, codice_isbn)`.

Lo stesso libro adottato in più anni_corso appare come righe separate. Questa è la forma onesta: "italiano 1ª" e "italiano 2ª" sono mercati distinti con quote distinte. `tipo_scuola` non compare in UI ma è usato come chiave di match col nazionale.

## Modifiche al model `AdozioniAnalytics`

### `mie_adozioni(filtri:)`

Group aggiornato:

```ruby
scope.group(
  "scuole.grado", "scuole.tipo_scuola", "classi.anno_corso",
  :disciplina, :titolo, :editore, :codice_isbn
).select(
  "scuole.grado AS grado",
  "scuole.tipo_scuola AS tipo_scuola",
  "classi.anno_corso AS anno_corso",
  :disciplina, :titolo, :editore, :codice_isbn,
  "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
  "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate",
  "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
).order("scuole.grado", :disciplina, "classi.anno_corso",
        Arel.sql("COUNT(DISTINCT adozioni.classe_id) DESC"))
```

### Nuovi metodi

Tre metodi pubblici, tutti appoggiati su due helper privati `book_shares(rows, codici_ministeriali:)` e `market_totals(rows, codici_ministeriali:)` che condividono la logica SQL (filtrata per scuole se `codici_ministeriali` presente, nazionale altrimenti):

- `#zone_market_totals(rows, codici_ministeriali:)` → totale mercato nella zona (denominatore Mia %)
- `#national_book_shares(rows)` → sezioni nazionali per libro (numeratore Naz. %)
- `#national_market_totals(rows)` → totale mercato nazionale (denominatore Naz. %)

`#national_book_shares(rows)` → `{ [grado, tipo, disc, anno, isbn] => sezioni_naz }`

```sql
SELECT im_sc."GRADO", im_sc."TIPOSCUOLA",
       im_ad."DISCIPLINA", im_ad."ANNOCORSO", im_ad."CODICEISBN",
       COUNT(DISTINCT im_ad."CODICESCUOLA" || '_' ||
                      im_ad."ANNOCORSO"    || '_' ||
                      im_ad."SEZIONEANNO") AS sezioni
FROM import_adozioni im_ad
JOIN import_scuole im_sc ON im_sc."CODICESCUOLA" = im_ad."CODICESCUOLA"
WHERE im_ad."DAACQUIST" = 'Si'
  AND (im_sc."GRADO", im_sc."TIPOSCUOLA", im_ad."DISCIPLINA",
       im_ad."ANNOCORSO", im_ad."CODICEISBN") IN (:tuples)
GROUP BY 1, 2, 3, 4, 5
```

`#national_market_totals(rows)` → `{ [grado, tipo, disc, anno] => totale_naz }`

Stessa forma ma senza vincolo ISBN e senza CODICEISBN nel GROUP BY. Tuple derivate dal distinct `(grado, tipo_scuola, disciplina, anno_corso)` delle righe mie.

### Performance

- Entrambe le query sono limitate dalle tuple presenti nelle mie righe (~100–500 libri distinti attesi).
- Servono indici (se non presenti) su `import_adozioni(CODICEISBN, ANNOCORSO, DISCIPLINA)` e `import_scuole(CODICESCUOLA)`.
- Da verificare in corso d'opera col profile reale.

## Modifiche al controller

`AdozioniAnalyticsController#show`:

```ruby
if @tab == "mie"
  @rows = @analytics.mie_adozioni(filtri: @filtri).to_a
  @national_book   = @analytics.national_book_shares(@rows)
  @national_totals = @analytics.national_market_totals(@rows)
  # ... opzioni filtri come oggi
end
```

Il partial riceve `@rows`, `@national_book`, `@national_totals`.

## Modifiche alla view

### `show.html.erb`

Nav ridotta a solo "Le mie":

```erb
<nav class="stats-nav">
  <%= link_to "Le mie", adozioni_analytics_path(tab: "mie", **@filtri),
              class: "stats-nav__link is-active" %>
  <%# Tab temporaneamente nascosti — agenzia, confronto, dati %>
</nav>
```

Partials e metodi model per gli altri tab **restano in codice**, non vengono renderizzati.

### `_tab_mie.html.erb`

Ristrutturazione:

- **Livello 1**: header per `grado`.
- **Livello 2**: un blocco `analytics-group` per `(disciplina, anno_corso)` con titolo `"Italiano · 1ª"` e sub-label con sezioni tue/naz del mercato.
- **Tabella** (colonne): Titolo · Editore · Sez. · Mia % · Naz. % · Δ · Copie · Disd.

Calcolo in view:

```erb
<% mercato_sezioni_mie = adozioni.sum { |r| r.sezioni_count.to_i } %>
<% adozioni.each do |row| %>
  <% mia_pct = 100.0 * row.sezioni_count.to_i / mercato_sezioni_mie %>
  <% naz_key = [row.grado, row.tipo_scuola, row.disciplina, row.anno_corso] %>
  <% naz_tot = @national_totals[naz_key].to_i %>
  <% naz_sez = @national_book[naz_key + [row.codice_isbn]].to_i %>
  <% naz_pct = naz_tot > 0 ? 100.0 * naz_sez / naz_tot : 0 %>
  <% delta   = mia_pct - naz_pct %>
  ...
<% end %>
```

Delta formattato con segno esplicito e classi `txt-positive` / `txt-negative` / `txt-subtle`.

## Fuori scope

- Aggregati nazionali nelle summary card in alto.
- Modifiche a `_filtri.html.erb`.
- Eliminazione dei tab nascosti (solo commento/hide, non rimozione).

## Rischi

- Valori di `scuole.tipo_scuola` potrebbero non matchare esattamente `import_scuole.TIPOSCUOLA`. Verificare con un SQL di controllo; se divergono, aggiungere normalizzatore.
- Molti ISBN mie potrebbero non esistere in `import_adozioni` (libri appena pubblicati). `naz_% = 0` è accettabile, ma vale la pena contare quanti sono.
