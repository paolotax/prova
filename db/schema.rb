# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_01_10_180328) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "import_adozioni", force: :cascade do |t|
    t.string "CODICESCUOLA"
    t.string "ANNOCORSO"
    t.string "SEZIONEANNO"
    t.string "TIPOGRADOSCUOLA"
    t.string "COMBINAZIONE"
    t.string "DISCIPLINA"
    t.string "CODICEISBN"
    t.string "AUTORI"
    t.string "TITOLO"
    t.string "SOTTOTITOLO"
    t.string "VOLUME"
    t.string "EDITORE"
    t.string "PREZZO"
    t.string "NUOVAADOZ"
    t.string "DAACQUIST"
    t.string "CONSIGLIATO"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false

    t.unique_constraint ["CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "TIPOGRADOSCUOLA", "COMBINAZIONE", "CODICEISBN", "NUOVAADOZ", "DAACQUIST", "CONSIGLIATO"], name: "import_adozioni_pk"
  end

  create_table "import_scuole", force: :cascade do |t|
    t.string "ANNOSCOLASTICO"
    t.string "AREAGEOGRAFICA"
    t.string "REGIONE"
    t.string "PROVINCIA"
    t.string "CODICEISTITUTORIFERIMENTO"
    t.string "DENOMINAZIONEISTITUTORIFERIMENTO"
    t.string "CODICESCUOLA"
    t.string "DENOMINAZIONESCUOLA"
    t.string "INDIRIZZOSCUOLA"
    t.string "CAPSCUOLA"
    t.string "CODICECOMUNESCUOLA"
    t.string "DESCRIZIONECOMUNE"
    t.string "DESCRIZIONECARATTERISTICASCUOLA"
    t.string "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
    t.string "INDICAZIONESEDEDIRETTIVO"
    t.string "INDICAZIONESEDEOMNICOMPRENSIVO"
    t.string "INDIRIZZOEMAILSCUOLA"
    t.string "INDIRIZZOPECSCUOLA"
    t.string "SITOWEBSCUOLA"
    t.string "SEDESCOLASTICA"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["CODICESCUOLA"], name: "index_import_scuole_on_CODICESCUOLA", unique: true
  end

  create_table "imports", force: :cascade do |t|
    t.string "fornitore"
    t.string "iva_fornitore"
    t.string "cliente"
    t.string "iva_cliente"
    t.string "tipo_documento"
    t.string "numero_documento"
    t.date "data_documento"
    t.float "totale_documento"
    t.integer "riga"
    t.string "codice_articolo"
    t.string "descrizione"
    t.float "prezzo_unitario"
    t.integer "quantita"
    t.float "importo_netto"
    t.float "sconto"
    t.integer "iva"
  end

  create_table "user_scuole", force: :cascade do |t|
    t.bigint "import_scuola_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_scuola_id"], name: "index_user_scuole_on_import_scuola_id"
    t.index ["user_id"], name: "index_user_scuole_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "partita_iva"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "user_scuole", "import_scuole"
  add_foreign_key "user_scuole", "users"

  create_view "view_documenti", sql_definition: <<-SQL
      SELECT DISTINCT concat(fornitore, '-', numero_documento, '-', data_documento) AS id,
      fornitore,
      iva_fornitore,
      cliente,
      iva_cliente,
      tipo_documento,
      numero_documento,
      data_documento,
          CASE
              WHEN ((tipo_documento)::text = ANY ((ARRAY['Nota di accredito'::character varying, 'TD04'::character varying])::text[])) THEN (- sum(quantita))
              ELSE sum(quantita)
          END AS quantita_totale,
          CASE
              WHEN ((tipo_documento)::text = ANY ((ARRAY['Nota di accredito'::character varying, 'TD04'::character varying])::text[])) THEN (- round(sum((importo_netto * (100)::double precision))))
              ELSE round(sum((importo_netto * (100)::double precision)))
          END AS importo_netto_totale,
          CASE
              WHEN ((tipo_documento)::text = ANY ((ARRAY['Nota di accredito'::character varying, 'TD04'::character varying])::text[])) THEN (- round((totale_documento * (100)::double precision)))
              ELSE round((totale_documento * (100)::double precision))
          END AS totale_documento,
          CASE
              WHEN ((iva_fornitore)::text = '04155820378'::text) THEN 'c.vendite'::text
              ELSE 'c.acquisti'::text
          END AS conto,
      (round((totale_documento * (100)::double precision)) - round((sum(importo_netto) * (100)::double precision))) AS "check"
     FROM imports
    GROUP BY fornitore, iva_fornitore, cliente, iva_cliente, tipo_documento, numero_documento, data_documento, totale_documento
    ORDER BY fornitore, data_documento DESC, numero_documento, tipo_documento;
  SQL
  create_view "view_righe", sql_definition: <<-SQL
      SELECT id,
      fornitore,
      iva_fornitore,
      cliente,
      iva_cliente,
      tipo_documento,
      numero_documento,
      data_documento,
          CASE
              WHEN ((tipo_documento)::text = 'Nota di accredito'::text) THEN (- totale_documento)
              ELSE totale_documento
          END AS totale_documento,
      riga,
      codice_articolo,
      descrizione,
      prezzo_unitario,
          CASE
              WHEN ((tipo_documento)::text = 'Nota di accredito'::text) THEN (- quantita)
              ELSE quantita
          END AS quantita,
          CASE
              WHEN ((tipo_documento)::text = 'Nota di accredito'::text) THEN (- importo_netto)
              ELSE importo_netto
          END AS importo_netto,
      sconto,
      iva,
          CASE
              WHEN ((iva_fornitore)::text = (( SELECT users.partita_iva
                 FROM users
               LIMIT 1))::text) THEN 'c.vendita'::text
              ELSE 'c.acquisti'::text
          END AS conto
     FROM imports;
  SQL
  create_view "view_articoli", sql_definition: <<-SQL
      SELECT DISTINCT codice_articolo,
      descrizione,
      sum(quantita) AS giacenza,
      sum(round((importo_netto * (100)::double precision))) AS valore
     FROM view_righe
    GROUP BY codice_articolo, descrizione
    ORDER BY codice_articolo;
  SQL
  create_view "view_fornitori", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      fornitore,
      iva_fornitore
     FROM view_documenti
    WHERE ((iva_cliente)::text = (( SELECT users.partita_iva
             FROM users
           LIMIT 1))::text)
    GROUP BY fornitore, iva_fornitore;
  SQL
  create_view "view_clienti", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      cliente,
      iva_cliente
     FROM view_documenti
    WHERE ((iva_fornitore)::text = (( SELECT users.partita_iva
             FROM users
           LIMIT 1))::text)
    GROUP BY cliente, iva_cliente;
  SQL
end
