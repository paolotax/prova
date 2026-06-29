# Passaggio anno EE — split e accorpamento classi (riconciliazione roster da new_adozioni) — Design

**Goal:** Rendere il passaggio anno della primaria (EE) corretto quando una classe **si sdoppia**
(`1A → 2A + 2B`) o **si accorpa** (`1A + 1B → 2A`). Oggi `Scuola#promuovi_primaria!` fa avanzamento
in-place 1:1 (`anno_corso + 1`, stessa sezione): comodo e a continuità preservata per il caso normale,
ma **sbaglia** su split/merge perché *assume* una lineage (la sezione A continua come A) che in quei
casi non è vera. La verità sul roster dell'anno è in `new_adozioni`.

**Scope:** SOLO primaria (EE), progressione lineare 1→5. Medie/superiori (progressione non lineare —
es. professionali con biennio/triennio invertiti, dove split/merge sono ancora più evidenti) restano
**fuori**, ma il modello "riconciliazione su roster, non su lineage" è quello che useremo anche lì.

**Tech Stack:** Rails 8.1, PostgreSQL (UUID, indici parziali/compositi), Minitest + fixtures.

---

## Decisione di fondo: filosofia A (N+1 + riconciliazione dei delta)

Si mantiene l'avanzamento in-place come **euristica best-effort** per il caso 1:1 (preserva la
continuità — documenti, appunti, persone, tappe restano agganciati alla **stessa** riga `Classe`, che
è l'entità durevole che attraversa gli anni). Si aggiunge una **riconciliazione del roster** contro
`new_adozioni` dell'anno target che gestisce split/merge ai bordi con create + archive.

Scartata la filosofia B ("roster puro": archivia tutto e ricrea ogni classe da `new_adozioni`): è
sempre corretta sul roster ma **perde ogni continuità** — è esattamente il vecchio comportamento
basato su `import_scuola` che staccava appunti/documenti.

**Lineage non ricostruibile:** da `new_adozioni` vediamo il roster *target* dell'anno, non "chi è
confluito dove". L'euristica "stessa sezione avanza" è il meglio possibile coi dati disponibili;
split/merge li gestiamo sul **roster**, non sulla lineage.

---

## Algoritmo core (decisione a tre vie + creazione)

Prima del loop, una volta sola, dal `new_adozioni` della scuola (codicescuola = `codice_ministeriale`
corrente, `tipogradoscuola "EE"`):

- **`roster`** = insieme delle terne `(annocorso, sezioneanno, combinazione)` che *dovrebbero* esistere
  l'anno `a`;
- **`gradi_coperti`** = i gradi (`annocorso`) realmente presenti in `new_adozioni` — è la rete di
  sicurezza della guardia **per-grado**.

Poi, per ogni classe attiva dell'anno `da` (ordine `anno_corso::int DESC`, come oggi, per evitare la
collisione 5ª-archiviata vs 4ª-promossa sull'unique index parziale):

1. **Grado 5 → archivia in identità originale** (la 5ª si diploma, resta `5A/da` come tombstone).
   Invariato.
2. Calcolo l'identità avanzata `(anno_corso + 1, sezione, combinazione)`:
   - **grado avanzato ∉ `gradi_coperti`** → dato MIUR mancante per quel grado → **avanza in-place**
     (default conservativo: niente archive);
   - grado avanzato ∈ `gradi_coperti` **e** identità ∈ `roster` → **avanza in-place** (caso normale
     1:1, continuità preservata);
   - grado avanzato ∈ `gradi_coperti` **ma** identità ∉ `roster` → **perdente** (merge loser / sezione
     soppressa) → **archivia in identità originale** (resta `1B/da`, **non** avanza, così lo storico
     per-libro resta coerente).

Punto chiave: i perdenti **non** vengono avanzati e poi spenti — restano la loro vera identità storica.
Niente tagging fittizio (no `2B/a` archiviata che non è mai esistita).

Dopo il loop:

**A. Build adozioni delle classi avanzate** — per ogni attiva `per_anno(a)`,
`costruisci_adozioni!(anno_scolastico: a)`. Le adozioni storiche (anno `da`) restano taggate e
agganciate alla stessa `Classe`: modello "storia per libro" intatto.

**B. Crea le classi mancanti** — `roster` meno le terne già coperte da classi attive `per_anno(a)`;
per ogni terna rimasta `find_or_create_by!(anno_corso:, sezione:, combinazione:, anno_scolastico: a,
stato: "attiva")` con i `*_origine` valorizzati, poi `costruisci_adozioni!(anno_scolastico: a)`.

Da questo passo cadono fuori **sia** lo split (la `2B` che nasce accanto alla `2A` avanzata) **sia** le
nuove prime (annocorso "1"): `crea_classi_prime!` diventa un sottoinsieme di `crea_classi_mancanti!` e
si **unifica**.

---

## Comportamento sui casi

- **Split `1A → 2A + 2B`**: la `1A` avanza a `2A` (vincitrice, in roster, stesso id → continuità
  appunti/documenti). La `2B` (in roster, non coperta) viene **creata** nuova con le sue adozioni.
- **Merge `1A + 1B → 2A`** (`new_adozioni` grado 2 ha solo `A`): la `1A` avanza a `2A` (vincitrice). La
  `1B` resta **`1B/da` archiviata** (perdente, non avanzata); i suoi documenti/appunti restano
  agganciati e recuperabili. La `find_or_create_by!` del passo B trova la `2A` esistente, non duplica.
- **Grado assente da `new_adozioni`**: tutte le classi di quel grado **avanzano comunque** e **non**
  vengono archiviate (guardia per-grado: dato mancante ≠ grado svuotato).
- **`new_adozioni` totalmente vuoto**: puro N+1, nessun archive, nessuna creazione.

---

## Idempotenza, vincoli, edge

- **Guardia idempotenza** (invariata): blocco avanzamento + riconciliazione dentro
  `unless classi.attive.per_anno(a).exists?`. Secondo run → skip. Lo spostamento maestri resta fuori
  dalla guardia (sempre ri-applicabile, come oggi).
- **Unique index parziale** `WHERE stato='attiva'` su `(scuola_id, anno_corso, sezione, combinazione)`:
  l'avanzamento DESC + il non-avanzare-i-perdenti garantiscono nessuna doppia *attiva* con la stessa
  terna in transazione. I perdenti escono dal vincolo passando subito a `archiviata`. La
  `find_or_create_by!` matcha esattamente la terna → niente collisione.
- **Edge accettati per EE (YAGNI, da rivedere per superiori):**
  - *Cambio `combinazione`* a parità di sezione (`2A-MQ` → `2A-""`) sarebbe letto come archive+create
    invece che continuità. In EE `combinazione` è di fatto stabile → accettato e documentato.
  - *Lineage non ricostruibile* (vedi sopra).

---

## Naming / file toccati

- `app/models/scuola.rb` — `promuovi_primaria!`: decisione a tre vie inline nel loop con
  `roster`/`gradi_coperti` calcolati prima; `crea_classi_prime!` → **`crea_classi_mancanti!`**
  (generalizzata a tutti i gradi).
- `app/models/classe.rb` — invariato (`new_adozioni`, `costruisci_adozioni!`, scope già esistenti).
- Nessuna migration nuova: le colonne `anno_scolastico`/`stato`/indici esistono già dal piano
  `2026-06-28-passaggio-anno-storicizzazione-primaria-plan.md`.

---

## Test

Estende `test/integration/passaggio_anno_ee_test.rb` (caso lineare 1:1 già coperto). Minitest +
fixtures.

**Fixture** in `new_adozioni.yml`: scuola di test con grado 2 sezioni `A` **e** `B` (split); scenario
con grado 2 solo `A` (merge); un grado interamente assente (guardia per-grado).

**Casi:**

1. **Split `1A → 2A + 2B`** — partenza `1A/da` + adozioni + un appunto/documento agganciato. Dopo
   `promuovi_primaria!`: la `1A` è `2A` attiva **stesso id** (assert id → continuità); esiste `2B`
   attiva **nuova** (id diverso) con adozioni da `new_adozioni`.
2. **Merge `1A + 1B → 2A`** — dopo: `2A` attiva (ex `1A`, stesso id); `1B` **archiviata**, ancora
   `anno_corso "1"` / `anno_scolastico da` (assert: non avanzata), documenti/appunti agganciati.
3. **Guardia per-grado** — grado assente da `new_adozioni`: la classe avanza e **non** è archiviata.
4. **`new_adozioni` vuoto** — puro N+1, nessun archive, nessuna creazione.
5. **Idempotenza** — secondo run: invariato il numero di attive `per_anno(a)`, nessuna adozione
   duplicata, nessun perdente ri-archiviato diversamente.
6. **Unit** in `scuola_test.rb`/`classe_test.rb`: `crea_classi_mancanti!` crea solo le terne mancanti;
   decisione a tre vie su una singola classe.

Verifica: `docker exec prova-app-1 bin/rails test` verde, con skill `verification-before-completion`
prima del done.

---

## Cosa NON è in questo design

- Medie/superiori (progressione non lineare: mappa per `tipo_scuola`). Il modello "riconciliazione su
  roster" è riusabile, ma la decisione "avanza vs archivia" lì non è `anno_corso + 1`.
- Ricostruzione della **lineage** split/merge (chi è confluito dove): non derivabile da `new_adozioni`.
- Cambio di `CODICESCUOLA` / maschera remap: già coperti dal piano precedente.
