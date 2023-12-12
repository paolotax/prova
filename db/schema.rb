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

ActiveRecord::Schema[7.1].define(version: 2023_12_12_112141) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "partita_iva"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end


  create_view "prova", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      imports.fornitore,
      imports.iva_fornitore,
      imports.cliente,
      imports.iva_cliente,
      imports.tipo_documento,
      imports.numero_documento,
      imports.data_documento,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- sum(imports.quantita))
              ELSE sum(imports.quantita)
          END AS quantita_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- round(sum((imports.importo_netto * (100)::double precision))))
              ELSE round(sum((imports.importo_netto * (100)::double precision)))
          END AS importo_netto_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- round((imports.totale_documento * (100)::double precision)))
              ELSE round((imports.totale_documento * (100)::double precision))
          END AS totale_documento,
          CASE
              WHEN ((imports.iva_fornitore)::text = '04155820378'::text) THEN 'c.vendite'::text
              ELSE 'c.acquisti'::text
          END AS conto,
      (round((imports.totale_documento * (100)::double precision)) - round((sum(imports.importo_netto) * (100)::double precision))) AS "check"
     FROM imports
    GROUP BY imports.fornitore, imports.iva_fornitore, imports.cliente, imports.iva_cliente, imports.tipo_documento, imports.numero_documento, imports.data_documento, imports.totale_documento
    ORDER BY imports.fornitore, imports.data_documento DESC, imports.numero_documento, imports.tipo_documento;
  SQL
  create_view "view_documenti", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      imports.fornitore,
      imports.iva_fornitore,
      imports.cliente,
      imports.iva_cliente,
      imports.tipo_documento,
      imports.numero_documento,
      imports.data_documento,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- sum(imports.quantita))
              ELSE sum(imports.quantita)
          END AS quantita_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- round(sum((imports.importo_netto * (100)::double precision))))
              ELSE round(sum((imports.importo_netto * (100)::double precision)))
          END AS importo_netto_totale,
          CASE
              WHEN ((imports.tipo_documento)::text = ANY (ARRAY[('Nota di accredito'::character varying)::text, ('TD04'::character varying)::text])) THEN (- round((imports.totale_documento * (100)::double precision)))
              ELSE round((imports.totale_documento * (100)::double precision))
          END AS totale_documento,
          CASE
              WHEN ((imports.iva_fornitore)::text = '04155820378'::text) THEN 'c.vendite'::text
              ELSE 'c.acquisti'::text
          END AS conto,
      (round((imports.totale_documento * (100)::double precision)) - round((sum(imports.importo_netto) * (100)::double precision))) AS "check"
     FROM imports
    GROUP BY imports.fornitore, imports.iva_fornitore, imports.cliente, imports.iva_cliente, imports.tipo_documento, imports.numero_documento, imports.data_documento, imports.totale_documento
    ORDER BY imports.fornitore, imports.data_documento DESC, imports.numero_documento, imports.tipo_documento;
  SQL
  create_view "view_righe", sql_definition: <<-SQL
      SELECT imports.id,
      imports.fornitore,
      imports.iva_fornitore,
      imports.cliente,
      imports.iva_cliente,
      imports.tipo_documento,
      imports.numero_documento,
      imports.data_documento,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.totale_documento)
              ELSE imports.totale_documento
          END AS totale_documento,
      imports.riga,
      imports.codice_articolo,
      imports.descrizione,
      imports.prezzo_unitario,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.quantita)
              ELSE imports.quantita
          END AS quantita,
          CASE
              WHEN ((imports.tipo_documento)::text = 'Nota di accredito'::text) THEN (- imports.importo_netto)
              ELSE imports.importo_netto
          END AS importo_netto,
      imports.sconto,
      imports.iva,
          CASE
              WHEN ((imports.iva_fornitore)::text = (( SELECT users.partita_iva
                 FROM users
               LIMIT 1))::text) THEN 'c.vendita'::text
              ELSE 'c.acquisti'::text
          END AS conto
     FROM imports;
  SQL
  create_view "view_articoli", sql_definition: <<-SQL
      SELECT DISTINCT view_righe.codice_articolo,
      view_righe.descrizione,
      sum(view_righe.quantita) AS giacenza,
      sum(round((view_righe.importo_netto * (100)::double precision))) AS valore
     FROM view_righe
    WHERE ((view_righe.codice_articolo IS NOT NULL) AND ((view_righe.codice_articolo)::text <> ''::text))
    GROUP BY view_righe.codice_articolo, view_righe.descrizione
    ORDER BY view_righe.codice_articolo;
  SQL
  create_view "view_fornitori", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      view_documenti.fornitore,
      view_documenti.iva_fornitore
     FROM view_documenti
    WHERE ((view_documenti.iva_cliente)::text = (( SELECT users.partita_iva
             FROM users
           LIMIT 1))::text)
    GROUP BY view_documenti.fornitore, view_documenti.iva_fornitore;
  SQL
  create_view "view_clienti", sql_definition: <<-SQL
      SELECT DISTINCT (row_number() OVER (PARTITION BY true::boolean))::integer AS id,
      view_documenti.cliente,
      view_documenti.iva_cliente
     FROM view_documenti
    WHERE ((view_documenti.iva_fornitore)::text = (( SELECT users.partita_iva
             FROM users
           LIMIT 1))::text)
    GROUP BY view_documenti.cliente, view_documenti.iva_cliente;
  SQL
end
