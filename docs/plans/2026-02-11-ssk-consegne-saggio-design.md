# SSK → ConsegnaSaggio: Design

## Problema
SSK (saggi, seguiti, kit) sono salvati come Appunti ma rappresentano consegne di copie saggio a classi con libri in adozione. Devono essere in una tabella dedicata legata ad Adozione.

## Nuova tabella: `consegne_saggio`

| Colonna | Tipo | Note |
|---------|------|------|
| id | uuid | PK |
| account_id | uuid | FK accounts |
| user_id | bigint | FK users |
| adozione_id | uuid | FK adozioni |
| tipo | string | "saggio" / "kit" / "seguito" |
| libro_id | bigint | FK libri (nullable) |
| quantita | integer | default 1 |
| note | text | |

## Tipi

- **saggio**: copie omaggio del titolo in adozione. `libro_id` = `adozione.libro_id`
- **kit**: libro sintetico "KIT 2025 DISCIPLINA CLASSE" in categoria "kit". `libro_id` = libro sintetico
- **seguito**: da rivedere. `libro_id` = nil, `note` = body dell'appunto originale

## Libri sintetici per Kit

- Categoria "kit" creata per ogni user
- Titolo: "KIT {anno_scolastico} {DISCIPLINA} {ANNOCORSO}" (dall'import_adozione)
- codice_isbn: "KIT-{DISCIPLINA}-{ANNOCORSO}-{user_id}" (unique per user)
- prezzo_in_cents: 0

## Migrazione dati (rake task)

Join path per trovare l'Adozione:
```
Appunto.import_adozione_id → ImportAdozione
  → CODICESCUOLA/ANNOCORSO/SEZIONEANNO → Classe (via codice_ministeriale_origine/classe_origine/sezione_origine)
  → Adozione (via classe_id + codice_isbn = CODICEISBN)
```

Per ogni Appunto SSK:
1. Trova import_adozione
2. Trova Classe account-scoped
3. Trova Adozione (classe + isbn)
4. Crea ConsegnaSaggio con tipo/libro/quantita
5. Log warning se Adozione non trovata

## Associazioni

```ruby
# Adozione
has_many :consegne_saggio, dependent: :destroy

# ConsegnaSaggio
belongs_to :adozione
belongs_to :user
belongs_to :libro, optional: true
```

## File da modificare dopo migrazione

- `app/models/entry.rb` — rimuovere `non_ssk` scope (non serve più)
- `app/views/import_adozioni/_card_ssk.html.erb` — puntare a consegne_saggio
- `app/models/scuole/foglio_scuola.rb` — aggiornare `ssk` method
- `app/models/import_adozione.rb` — rimuovere has_many saggi/seguiti/kit
