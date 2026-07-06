namespace :miur do
  desc "Backfill one-shot delle swing tables in miur_adozioni/miur_scuole"
  task backfill: :environment do
    conn = ActiveRecord::Base.connection

    {"202425" => "old_adozioni", "202627" => "new_adozioni"}.each do |anno, tab|
      conn.execute("TRUNCATE miur_adozioni_#{anno}")
      conn.execute(<<~SQL)
        INSERT INTO miur_adozioni
          (id, anno_scolastico, annocorso, autori, codiceisbn, codicescuola, combinazione,
           consigliato, daacquist, disciplina, editore, nuovaadoz, prezzo, sezioneanno,
           sottotitolo, tipogradoscuola, titolo, volume, import_scuola_id)
        SELECT id, '#{anno}', annocorso, autori, codiceisbn, codicescuola, combinazione,
               consigliato, daacquist, disciplina, editore, nuovaadoz, prezzo, sezioneanno,
               sottotitolo, tipogradoscuola, titolo, volume, import_scuola_id
        FROM #{tab}
      SQL
      puts "#{anno}: #{conn.select_value("SELECT count(*) FROM miur_adozioni_#{anno}")} righe da #{tab}"
    end

    conn.execute("TRUNCATE miur_adozioni_202526")
    conn.execute(<<~SQL)
      INSERT INTO miur_adozioni
        (id, anno_scolastico, annocorso, autori, codiceisbn, codicescuola, combinazione,
         consigliato, daacquist, disciplina, editore, nuovaadoz, prezzo, sezioneanno,
         sottotitolo, tipogradoscuola, titolo, volume)
      SELECT id, '202526', "ANNOCORSO", "AUTORI", "CODICEISBN", "CODICESCUOLA", "COMBINAZIONE",
             "CONSIGLIATO", "DAACQUIST", "DISCIPLINA", "EDITORE", "NUOVAADOZ", "PREZZO",
             "SEZIONEANNO", "SOTTOTITOLO", "TIPOGRADOSCUOLA", "TITOLO", "VOLUME"
      FROM import_adozioni
    SQL
    puts "202526: #{conn.select_value("SELECT count(*) FROM miur_adozioni_202526")} righe da import_adozioni"

    conn.execute("TRUNCATE miur_scuole_202627")
    conn.execute(<<~SQL)
      INSERT INTO miur_scuole
        (id, anno_scolastico, area_geografica, cap, codice_comune, codice_istituto_riferimento,
         codice_scuola, comune, denominazione, denominazione_istituto_riferimento,
         descrizione_caratteristica, email, indicazione_sede_direttivo,
         indicazione_sede_omnicomprensivo, indirizzo, pec, provincia, regione,
         sede_scolastica, sito_web, tipo_scuola, import_scuola_id)
      SELECT id, anno_scolastico, area_geografica, cap, codice_comune, codice_istituto_riferimento,
             codice_scuola, comune, denominazione, denominazione_istituto_riferimento,
             descrizione_caratteristica, email, indicazione_sede_direttivo,
             indicazione_sede_omnicomprensivo, indirizzo, pec, provincia, regione,
             sede_scolastica, sito_web, tipo_scuola, import_scuola_id
      FROM new_scuole
    SQL

    %w[miur_adozioni miur_scuole].each do |t|
      max = conn.select_value("SELECT COALESCE(MAX(id),1) FROM #{t}")
      conn.execute("SELECT setval(pg_get_serial_sequence('#{t}', 'id'), #{max})")
      conn.execute("ANALYZE #{t}")
    end
    puts "Backfill completato"
  end
end
