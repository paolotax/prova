# Passaggio anno guidato — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Design di riferimento: `docs/plans/2026-07-05-passaggio-anno-guidato-design.md`.
> **Git (CLAUDE.md override):** NON committare automaticamente — i punti "Commit" sono checkpoint da eseguire solo su richiesta esplicita dell'utente.

**Goal:** Sequenza guidata a 4 step nella dashboard controllo adozioni (e nel drill-down provincia) per eseguire in ordine i job del passaggio anno scolastico.

**Architecture:** Nuovo PORO `ControlloAdozioni::PassaggioAnno` che deriva i contatori dei 4 step con query SQL aggregate (stile `Dashboard`), incluso lo split match/suggerimento/nuova oggi calcolato solo in Ruby da `Panoramica#build_cambi_codice`. Un partial condiviso renderizza le step-card; le action controller e i job esistono già. Nessuna migrazione.

**Tech Stack:** Rails 8.1, PostgreSQL (CTE), Minitest, Turbo (morph già attivo sulla dashboard), CSS custom stile Fizzy (Propshaft, niente Tailwind).

---

## Contesto per chi implementa

- I 3 job e le 3 action POST esistono già: `ControlloAdozioniController#aggiorna_cambi_codice`, `#promuovi_tutte`, `#aggiungi_scuole_nuove` (`config/routes.rb:378-381`). Accettano `provincia` opzionale. Admin-only (`head :forbidden`).
- La classificazione dei codici nuovi (`:match` / `:suggerimento` / `:nuova`) vive in `app/models/controllo_adozioni/panoramica.rb` (`build_cambi_codice`, righe 255-309). Regole da replicare in SQL:
  - **orfana**: scuola account (provincia+grado della zona) il cui `codice_ministeriale` non compare più in `new_adozioni` per i `tipogradoscuola` del grado (`Panoramica::TG`), esclusa se è direzione di qualcuno (account-wide);
  - **candidata**: orfana con stesso `comune` e stessa natura (`tipo_scuola ILIKE '%NON STATALE%'` uguale da entrambi i lati);
  - **predecessore certo (match)**: esattamente UNA candidata con denominazione "simile" = uguale dopo normalizzazione (upcase, non-[A-Z0-9 ]→spazio, collasso spazi, trim) oppure una contenuta nell'altra;
  - **suggerimento**: candidate > 0 ma senza match univoco; **nuova**: zero candidate.
- Pattern test di riferimento: `test/models/controllo_adozioni/dashboard_test.rb` — provincia sintetica "XX", `crea_tipo_primaria` (TipoScuola con `save!(validate: false)`), zona creata al volo. `fixtures :all` è DISABILITATO: dichiarare solo le fixture che servono.
- Comandi test: `docker exec prova-app-1 bin/rails test <path>`.

---

### Task 1: `PassaggioAnno` — conteggi codici nuovi per tipo (SQL) con guardia anti-deriva

**Files:**
- Create: `test/models/controllo_adozioni/passaggio_anno_test.rb`
- Create: `app/models/controllo_adozioni/passaggio_anno.rb`

**Step 1: scrivi il test che fallisce**

```ruby
require "test_helper"

module ControlloAdozioni
  class PassaggioAnnoTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @account = accounts(:fizzy)
      @anno = "202627"
      crea_tipo_primaria
      @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA", stato: "attiva")
    end

    def crea_tipo_primaria
      TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
        TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }
    end

    def passaggio(provincia: nil)
      PassaggioAnno.new(account: @account, provincia: provincia)
    end

    # Scuola account "orfana": codice non più presente in new_adozioni.
    def crea_orfana(codice:, denominazione:, comune: "TESTVILLE")
      @account.scuole.create!(codice_ministeriale: codice, provincia: "XX",
        comune: comune, denominazione: denominazione,
        tipo_scuola: "SCUOLA PRIMARIA", grado: "E", adozioni_count: 1)
    end

    # Codice nuovo MIUR: in new_scuole (anno target) con adozioni EE, assente dall'account.
    def crea_nuovo_codice(codice:, denominazione:, comune: "TESTVILLE", isbn:)
      NewScuola.create!(codice_scuola: codice, anno_scolastico: @anno, provincia: "XX",
        comune: comune, denominazione: denominazione, tipo_scuola: "SCUOLA PRIMARIA")
      NewAdozione.create!(codicescuola: codice, tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: isbn, daacquist: "Si")
    end

    test "classifica match, suggerimento e nuova come Panoramica" do
      # MATCH: un'orfana sola, denominazione simile (contenimento).
      crea_orfana(codice: "XXEE0000M1", denominazione: "Primaria Calamandrei")
      crea_nuovo_codice(codice: "XXEE0000M9", denominazione: "PIERO CALAMANDREI",
                        isbn: "9880000000011")

      # SUGGERIMENTO: due orfane simili nello stesso comune → nessun match univoco.
      crea_orfana(codice: "XXEE0000S1", denominazione: "Rodari", comune: "ALTROVE")
      crea_orfana(codice: "XXEE0000S2", denominazione: "Gianni Rodari", comune: "ALTROVE")
      crea_nuovo_codice(codice: "XXEE0000S9", denominazione: "RODARI", comune: "ALTROVE",
                        isbn: "9880000000029")

      # NUOVA: nessuna orfana nel comune.
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      p = passaggio
      assert_equal 1, p.conteggi_codici_nuovi[:match]
      assert_equal 1, p.conteggi_codici_nuovi[:suggerimento]
      assert_equal 1, p.conteggi_codici_nuovi[:nuova]
    end

    test "anti-deriva: stessi conteggi di Panoramica#cambi_codice sugli stessi dati" do
      crea_orfana(codice: "XXEE0000M1", denominazione: "Primaria Calamandrei")
      crea_nuovo_codice(codice: "XXEE0000M9", denominazione: "PIERO CALAMANDREI",
                        isbn: "9880000000011")
      crea_orfana(codice: "XXEE0000S1", denominazione: "Rodari", comune: "ALTROVE")
      crea_orfana(codice: "XXEE0000S2", denominazione: "Gianni Rodari", comune: "ALTROVE")
      crea_nuovo_codice(codice: "XXEE0000S9", denominazione: "RODARI", comune: "ALTROVE",
                        isbn: "9880000000029")
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      attesi = Panoramica.new(account: @account).cambi_codice
                         .group_by(&:tipo).transform_values(&:size)
      attesi.default = 0

      c = passaggio.conteggi_codici_nuovi
      assert_equal attesi[:match], c[:match]
      assert_equal attesi[:suggerimento], c[:suggerimento]
      assert_equal attesi[:nuova], c[:nuova]
    end

    test "le direzioni non sono candidate predecessore" do
      dir = crea_orfana(codice: "XXEE0000D1", denominazione: "Direzione Calamandrei")
      plesso = crea_orfana(codice: "XXEE0000D2", denominazione: "Altro Plesso")
      plesso.update_columns(direzione_id: dir.id)
      crea_nuovo_codice(codice: "XXEE0000M9", denominazione: "CALAMANDREI",
                        isbn: "9880000000011")

      # La direzione è esclusa dai candidati: resta solo "Altro Plesso" (non simile)
      # → suggerimento, non match.
      c = passaggio.conteggi_codici_nuovi
      assert_equal 0, c[:match]
      assert_equal 1, c[:suggerimento]
    end

    test "provincia scopa i conteggi" do
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      assert_equal 1, passaggio(provincia: "XX").conteggi_codici_nuovi[:nuova]
      assert_equal 0, passaggio(provincia: "MI").conteggi_codici_nuovi[:nuova]
    end

    test "senza snapshot MIUR la sequenza non è disponibile" do
      NewScuola.delete_all
      p = passaggio
      refute p.disponibile?
      assert_equal({ match: 0, suggerimento: 0, nuova: 0 }, p.conteggi_codici_nuovi)
    end
  end
end
```

**Step 2: verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/passaggio_anno_test.rb`
Expected: FAIL — `NameError: uninitialized constant ControlloAdozioni::PassaggioAnno`

**Step 3: implementazione**

`app/models/controllo_adozioni/passaggio_anno.rb`:

```ruby
module ControlloAdozioni
  # Sequenza guidata del passaggio anno scolastico: contatori dei 4 step derivati
  # dallo stato corrente, nessuna persistenza (step "fatto" = contatore a zero).
  # Lo split match/suggerimento/nuova replica in SQL le regole di
  # Panoramica#build_cambi_codice: il test anti-deriva li tiene allineati.
  class PassaggioAnno
    Step = Struct.new(:numero, :key, :titolo, :descrizione, :count, :job, keyword_init: true) do
      def done? = count.zero?
      def azionabile? = job.present? && count.positive?
    end

    def initialize(account:, provincia: nil)
      @account = account
      @provincia = provincia
    end

    attr_reader :account, :provincia

    def anno = @anno ||= NewScuola.maximum(:anno_scolastico)

    def disponibile? = anno.present?

    def steps
      @steps ||= [
        Step.new(numero: 1, key: :cambi_codice, job: :aggiorna_cambi_codice,
                 titolo: "Aggiorna i cambi codice",
                 descrizione: "Codici nuovi con predecessore certo: aggiorna il codice e promuove le classi.",
                 count: conteggi_codici_nuovi[:match]),
        Step.new(numero: 2, key: :promuovibili, job: :promuovi_tutte,
                 titolo: "Promuovi le scuole",
                 descrizione: "Scuole già in anagrafe con lo snapshot MIUR nuovo: crea classi e adozioni.",
                 count: promuovibili_count),
        Step.new(numero: 3, key: :scuole_nuove, job: :aggiungi_scuole_nuove,
                 titolo: "Aggiungi le scuole nuove",
                 descrizione: "Codici mai visti e senza candidati: entrano in anagrafe già riconciliate.",
                 count: conteggi_codici_nuovi[:nuova]),
        Step.new(numero: 4, key: :rifinitura, job: nil,
                 titolo: "Rifinitura manuale",
                 descrizione: "Suggerimenti da scegliere a mano e anomalie da controllare.",
                 count: conteggi_codici_nuovi[:suggerimento] + anomalie_count)
      ]
    end

    def conteggi_codici_nuovi
      @conteggi_codici_nuovi ||= begin
        counts = { match: 0, suggerimento: 0, nuova: 0 }
        zone_per_grado.each do |grado, zone|
          tg = Panoramica::TG[grado] || []
          tipi = TipoScuola.where(grado: grado).pluck(:tipo)
          next if tg.empty? || tipi.empty?

          ActiveRecord::Base.connection.select_all(
            ActiveRecord::Base.sanitize_sql(
              [SQL_CLASSIFICA, account_id: account.id, anno: anno,
               province: zone.map(&:provincia), tipi: tipi, tg: tg, grado: grado]
            )
          ).each { |r| counts[r["tipo"].to_sym] += r["n"].to_i }
        end
        counts
      end
    end

    def promuovibili_count
      @promuovibili_count ||= begin
        return 0 if anno.blank?

        scope = account.scuole.where.not(codice_ministeriale: [nil, ""])
        scope = scope.where(provincia: provincia) if provincia
        scope
          .where(NewScuola.where("new_scuole.codice_scuola = scuole.codice_ministeriale")
                          .where(anno_scolastico: anno).arel.exists)
          .where(NewAdozione.where("new_adozioni.codicescuola = scuole.codice_ministeriale")
                            .where(tipogradoscuola: "EE").arel.exists)
          .where.not(
            Classe.where("classi.scuola_id = scuole.id")
                  .where(stato: "attiva").where("classi.anno_scolastico >= ?", anno).arel.exists
          ).count
      end
    end

    def anomalie_count
      @anomalie_count ||= begin
        scope = account.scuole.where.not(codice_ministeriale: [nil, ""])
        scope = scope.where(provincia: provincia) if provincia
        scope.where(
          ControlloAnomalia.where("controllo_anomalie.codicescuola = scuole.codice_ministeriale").arel.exists
        ).count
      end
    end

    private

    def zone_per_grado
      return {} if anno.blank?

      zone = account.zone
      zone = zone.where(provincia: provincia) if provincia
      zone.group_by(&:grado)
    end

    # Normalizzazione denominazione identica a Panoramica#denom_norm:
    # upcase, non-[A-Z0-9 ] → spazio, collasso spazi, trim.
    NORM = "btrim(regexp_replace(regexp_replace(upper(COALESCE(%s, '')), " \
           "'[^A-Z0-9 ]', ' ', 'g'), ' +', ' ', 'g'))".freeze

    # Per ogni codice nuovo (new_scuole+new_adozioni della zona, assente dall'account)
    # conta le orfane candidate (stesso comune/provincia, stessa natura) e quelle con
    # denominazione simile; classifica come Panoramica: 1 simile → match,
    # candidate > 0 → suggerimento, altrimenti nuova.
    SQL_CLASSIFICA = <<~SQL.freeze
      WITH orfane AS (
        SELECT sc.provincia, sc.comune,
               COALESCE(sc.tipo_scuola, '') ILIKE '%NON STATALE%' AS paritaria,
               #{NORM % "sc.denominazione"} AS denom
        FROM scuole sc
        WHERE sc.account_id = :account_id
          AND sc.provincia IN (:province)
          AND sc.grado = :grado
          AND NOT EXISTS (SELECT 1 FROM new_adozioni na
                          WHERE na.codicescuola = sc.codice_ministeriale
                            AND na.tipogradoscuola IN (:tg))
          AND NOT EXISTS (SELECT 1 FROM scuole fig
                          WHERE fig.account_id = :account_id AND fig.direzione_id = sc.id)
      ),
      nuovi AS (
        SELECT ns.codice_scuola, ns.provincia, ns.comune,
               COALESCE(ns.tipo_scuola, '') ILIKE '%NON STATALE%' AS paritaria,
               #{NORM % "ns.denominazione"} AS denom
        FROM new_scuole ns
        WHERE ns.anno_scolastico = :anno
          AND ns.provincia IN (:province)
          AND ns.tipo_scuola IN (:tipi)
          AND EXISTS (SELECT 1 FROM new_adozioni na
                      WHERE na.codicescuola = ns.codice_scuola
                        AND na.tipogradoscuola IN (:tg))
          AND NOT EXISTS (SELECT 1 FROM scuole sc
                          WHERE sc.account_id = :account_id
                            AND sc.codice_ministeriale = ns.codice_scuola)
      )
      SELECT t.tipo, COUNT(*) AS n
      FROM (
        SELECT n.codice_scuola,
               CASE
                 WHEN COUNT(o.*) FILTER (
                        WHERE o.denom <> '' AND n.denom <> ''
                          AND (o.denom = n.denom
                               OR position(o.denom IN n.denom) > 0
                               OR position(n.denom IN o.denom) > 0)
                      ) = 1 THEN 'match'
                 WHEN COUNT(o.*) > 0 THEN 'suggerimento'
                 ELSE 'nuova'
               END AS tipo
        FROM nuovi n
        LEFT JOIN orfane o
          ON o.provincia = n.provincia AND o.comune = n.comune
         AND o.paritaria = n.paritaria
        GROUP BY n.codice_scuola
      ) t
      GROUP BY t.tipo
    SQL
  end
end
```

Nota per chi implementa: `Panoramica#build_cambi_codice` esclude le direzioni con
`direzione_ids` account-wide e raggruppa le orfane per comune **dentro la zona**
(quindi provincia implicita): il JOIN su `provincia + comune` replica entrambe.
`COUNT(o.*)` conta solo le righe realmente joinate (NULL su LEFT JOIN senza match).

**Step 4: verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/passaggio_anno_test.rb`
Expected: PASS (5 test). Se il test anti-deriva fallisce, il bug è quasi certamente nella SQL (normalizzazione o esclusione direzioni): confrontare con `Panoramica#build_cambi_codice` riga per riga, NON aggiustare il test.

**Step 5: checkpoint commit** (solo su richiesta dell'utente)
`feat(controllo-adozioni): conteggi passaggio anno con split match/suggerimento/nuova in SQL`

---

### Task 2: `PassaggioAnno#steps` + allineamento con Dashboard

**Files:**
- Modify: `test/models/controllo_adozioni/passaggio_anno_test.rb`
- Modify (solo se serve): `app/models/controllo_adozioni/passaggio_anno.rb`

**Step 1: aggiungi i test**

```ruby
    test "steps espone la sequenza con stato derivato" do
      crea_nuovo_codice(codice: "XXEE0000N9", denominazione: "PRIMARIA INEDITA",
                        comune: "COMUNE NUOVO", isbn: "9880000000037")

      steps = passaggio.steps
      assert_equal %i[cambi_codice promuovibili scuole_nuove rifinitura], steps.map(&:key)

      cambi = steps.find { |s| s.key == :cambi_codice }
      nuove = steps.find { |s| s.key == :scuole_nuove }
      assert cambi.done?
      refute cambi.azionabile?
      assert_equal 1, nuove.count
      assert nuove.azionabile?
      refute steps.find { |s| s.key == :rifinitura }.azionabile?, "step 4 non ha job"
    end

    test "promuovibili_count allineato a Dashboard da_promuovere" do
      scuola = crea_orfana(codice: "XXEE0000P1", denominazione: "Primaria Promuovibile")
      NewScuola.create!(codice_scuola: "XXEE0000P1", anno_scolastico: @anno, provincia: "XX",
        comune: "TESTVILLE", denominazione: "PRIMARIA PROMUOVIBILE", tipo_scuola: "SCUOLA PRIMARIA")
      NewAdozione.create!(codicescuola: "XXEE0000P1", tipogradoscuola: "EE",
        annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000045", daacquist: "Si")

      dashboard_xx = Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
      assert_equal dashboard_xx.da_promuovere, passaggio(provincia: "XX").promuovibili_count
      assert_equal 1, passaggio(provincia: "XX").promuovibili_count
    end
```

**Step 2: verifica**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/passaggio_anno_test.rb`
Expected: PASS se Task 1 è completo (steps è già implementato lì); altrimenti sistemare `steps`/`promuovibili_count` finché passa. Attenzione al confronto Dashboard: `promuovibile` in `Dashboard#sql_righe` richiede anche `COALESCE(codice_ministeriale,'') <> ''` e il filtro "con adozioni" — la fixture helper `crea_orfana` imposta `adozioni_count: 1` apposta.

**Step 3: checkpoint commit** (solo su richiesta)
`feat(controllo-adozioni): sequenza steps del passaggio anno`

---

### Task 3: partial `_passaggio_anno` + integrazione dashboard e drill-down

**Files:**
- Create: `app/views/controllo_adozioni/_passaggio_anno.html.erb`
- Modify: `app/views/controllo_adozioni/dashboard.html.erb` (render in cima + rimozione bottone "Promuovi i match" dalla card `codici_nuovi`, righe 30-36)
- Modify: `app/views/controllo_adozioni/index.html.erb` (render nel drill-down admin, dopo il link "← Tutte le province")
- Modify: `app/controllers/controllo_adozioni_controller.rb` (istanzia `@passaggio` nei due rami admin)
- Modify: `app/assets/stylesheets/analytics.css` (stili step-card)

**Step 1: controller**

In `index`, ramo dashboard (dopo `@dashboard = ...`):

```ruby
      @passaggio = ControlloAdozioni::PassaggioAnno.new(account: Current.account)
```

Nel ramo drill-down, subito prima di `@panoramica = ...`, solo per admin:

```ruby
    @passaggio = ControlloAdozioni::PassaggioAnno.new(account: Current.account, provincia: @provincia) if Current.admin?
```

**Step 2: partial**

`app/views/controllo_adozioni/_passaggio_anno.html.erb` — locals: `passaggio:`, `account_id:`, `provincia:` (nil sulla dashboard).

```erb
<% if passaggio.disponibile? %>
  <section class="passaggio-anno margin-block-end">
    <h2 class="txt-medium">
      Passaggio anno <%= anno_scolastico_label(passaggio.anno) %>
      <%= "· #{provincia}" if provincia %>
    </h2>
    <ol class="passaggio-anno__steps">
      <% passaggio.steps.each do |step| %>
        <li class="passaggio-anno__step <%= "passaggio-anno__step--done" if step.done? %>">
          <span class="passaggio-anno__numero"><%= step.done? ? "✓" : step.numero %></span>
          <p class="passaggio-anno__value"><%= step.count %></p>
          <p class="passaggio-anno__label"><%= step.titolo %></p>
          <p class="passaggio-anno__hint txt-x-small txt-subtle"><%= step.descrizione %></p>
          <% if step.azionabile? %>
            <%= button_to send("controllo_adozioni_#{step.job}_path", account_id: account_id, provincia: provincia),
                  class: "btn btn--small btn--accent",
                  data: { turbo_confirm: "#{step.titolo} (#{step.count})#{" — #{provincia}" if provincia}: avviare?" } do %>
              Avvia
            <% end %>
          <% elsif step.key == :rifinitura && step.count.positive? %>
            <%= link_to "Vedi anomalie",
                  controllo_adozioni_index_path(account_id: account_id, provincia: provincia, filtro: "anomalie"),
                  class: "btn btn--small" %>
          <% end %>
        </li>
      <% end %>
    </ol>
  </section>
<% end %>
```

Nota: `anno_scolastico_label` è in `AdozioniAnalyticsHelper` (helper globali Rails). I path helper: `controllo_adozioni_aggiorna_cambi_codice_path`, `controllo_adozioni_promuovi_tutte_path`, `controllo_adozioni_aggiungi_scuole_nuove_path` — `step.job` usa esattamente questi suffissi.

**Step 3: render nelle due viste**

In `dashboard.html.erb`, dopo `<div class="stats-container" ...>` (riga 12), prima delle card:

```erb
  <%= render "controllo_adozioni/passaggio_anno", passaggio: @passaggio,
        account_id: params[:account_id], provincia: nil %>
```

e RIMUOVI il blocco `button_to "Promuovi i match"` dalla card `codici_nuovi` (righe 30-36 attuali).

In `index.html.erb`, dentro `<% if Current.admin? && @provincia.present? %>` dopo il `<p>` col link "← Tutte le province":

```erb
    <%= render "controllo_adozioni/passaggio_anno", passaggio: @passaggio,
          account_id: params[:account_id], provincia: @provincia %>
```

**Step 4: CSS**

In `app/assets/stylesheets/analytics.css` (layer `modules`, coerente con `.analytics-summary`):

```css
.passaggio-anno__steps {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr));
  gap: var(--spacing-half, 0.5rem);
  list-style: none;
  padding: 0;
  counter-reset: none;
}

.passaggio-anno__step {
  position: relative;
  padding: var(--spacing-half, 0.5rem);
  border: 1px solid var(--color-border, #ddd);
  border-radius: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.passaggio-anno__step--done {
  opacity: 0.6;
}

.passaggio-anno__step--done .passaggio-anno__numero {
  background: var(--color-positive, #2e7d32);
  color: #fff;
}

.passaggio-anno__numero {
  inline-size: 1.5rem;
  block-size: 1.5rem;
  border-radius: 50%;
  background: var(--color-border, #ddd);
  display: grid;
  place-items: center;
  font-size: 0.8rem;
  font-weight: 600;
}

.passaggio-anno__value {
  font-size: 1.5rem;
  font-weight: 700;
  line-height: 1;
}

.passaggio-anno__label {
  font-weight: 600;
}
```

Adattare i nomi delle custom property a quelli reali di `analytics.css`/`_global.css` (guardare le regole `.analytics-summary__*` esistenti e riusare le stesse variabili).

**Step 5: verifica manuale rapida**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb`
Expected: PASS (i test esistenti non devono rompersi — in particolare quelli sulla dashboard).
Poi controllo visivo su dev (`localhost:3000`, account admin) di dashboard e drill-down.

**Step 6: checkpoint commit** (solo su richiesta)
`feat(controllo-adozioni): sequenza guidata passaggio anno in dashboard e drill-down`

---

### Task 4: controller test per la sezione

**Files:**
- Modify: `test/controllers/controllo_adozioni_controller_test.rb`

**Step 1: aggiungi i test**

Nel setup serve uno snapshot MIUR minimo perché la sezione compaia (`disponibile?`):
aggiungere in setup (o nei singoli test):

```ruby
    NewScuola.create!(codice_scuola: "MIEE99999X", anno_scolastico: "202627",
      provincia: "MI", comune: "Milano", denominazione: "PRIMARIA TEST",
      tipo_scuola: "SCUOLA PRIMARIA")
```

Test:

```ruby
  test "dashboard admin mostra la sequenza passaggio anno" do
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".passaggio-anno"
    assert_select ".passaggio-anno__step", 4
  end

  test "drill-down provincia mostra la sequenza scoped" do
    get controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
    assert_response :success
    assert_select ".passaggio-anno"
    # i button_to della sequenza portano la provincia
    assert_select ".passaggio-anno form[action*='provincia=MI']" do
      # almeno un form se c'è uno step azionabile; il selettore non deve dare errore
    end if css_select(".passaggio-anno form").any?
  end

  test "member non vede la sequenza passaggio anno" do
    sign_in_as(users(:two), @account)
    get controllo_adozioni_index_path(account_id: @account.id)
    assert_response :success
    assert_select ".passaggio-anno", count: 0
  end
```

Attenzione: il test esistente "dashboard: le card sono cliccabili..." non asserisce
il bottone "Promuovi i match" rimosso, quindi non va toccato. Verificare con
`grep -rn "Promuovi i match" test/ app/` che non restino riferimenti (deve
restare solo, eventualmente, nel partial `_cambi_codice` se ha un bottone suo —
quello NON va rimosso).

**Step 2: verifica**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb`
Expected: PASS (8 test).

**Step 3: suite completa dei file toccati**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/ test/controllers/controllo_adozioni_controller_test.rb`
Expected: PASS. (Nota: 3 failure PRE-ESISTENTI in `Stats::AdozioniQueryTest` se si lancia tutta la suite — non riguardano questo lavoro.)

**Step 4: checkpoint commit finale** (solo su richiesta)
`test(controllo-adozioni): copertura sequenza passaggio anno`

---

## Rischi noti

- **Deriva SQL ↔ Ruby**: coperta dal test anti-deriva (Task 1). Se in futuro si
  tocca `Panoramica#build_cambi_codice` (normalizzazione, natura, direzioni), il
  test fallisce e va aggiornata anche `SQL_CLASSIFICA`.
- **Costo query dashboard**: SQL_CLASSIFICA gira una volta per grado di zona
  (per un editore EE = 1 sola query, ~100 province). Le CTE scandiscono
  new_scuole/scuole filtrate per provincia+anno: stessi ordini di grandezza
  delle query già in `Dashboard`. Se lenta in prod: EXPLAIN e semmai indice su
  `new_scuole (anno_scolastico, provincia, tipo_scuola)` — non anticiparlo.
- **`send` sul path helper nel partial**: i tre `step.job` sono simboli interni
  hardcodati nel PORO, non input utente.
