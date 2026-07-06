# Popola miur_adozioni/miur_scuole dalle swing tables (old_adozioni,
# import_adozioni, new_adozioni, new_scuole) MENTRE ESISTONO ANCORA: la
# migrazione 20260706120000 le droppa subito dopo. Il timestamp e' scelto
# apposta per girare DOPO la creazione delle tabelle partizionate
# (20260706103351) e PRIMA del repoint delle matview (20260706110000) e del
# drop delle swing (20260706120000), cosi' un singolo `kamal deploy` esegue
# l'intera Fase 1 nell'ordine corretto senza passaggi manuali.
#
# Idempotente e guardata: se le swing tables non sono piu' TABELLE reali
# (gia' droppate, o rimpiazzate dalle viste ponte), la migrazione e' un no-op
# e non tocca le partizioni miur_* gia' popolate — evita il footgun di
# ricopiare da una vista ponte che legge le partizioni stesse.
class BackfillMiurFromSwingTables < ActiveRecord::Migration[8.1]
  def up
    unless swing_tables_present?
      say "Swing tables assenti come tabelle reali: backfill saltato (gia' consumato o ambiente nuovo)."
      return
    end

    { "202425" => "old_adozioni", "202627" => "new_adozioni" }.each do |anno, tab|
      execute "TRUNCATE miur_adozioni_#{anno}"
      execute(<<~SQL)
        INSERT INTO miur_adozioni
          (id, anno_scolastico, annocorso, autori, codiceisbn, codicescuola, combinazione,
           consigliato, daacquist, disciplina, editore, nuovaadoz, prezzo, sezioneanno,
           sottotitolo, tipogradoscuola, titolo, volume, import_scuola_id)
        SELECT id, '#{anno}', annocorso, autori, codiceisbn, codicescuola, combinazione,
               consigliato, daacquist, disciplina, editore, nuovaadoz, prezzo, sezioneanno,
               sottotitolo, tipogradoscuola, titolo, volume, import_scuola_id
        FROM #{tab}
      SQL
      say "#{anno}: #{select_value("SELECT count(*) FROM miur_adozioni_#{anno}")} righe da #{tab}"
    end

    execute "TRUNCATE miur_adozioni_202526"
    execute(<<~SQL)
      INSERT INTO miur_adozioni
        (id, anno_scolastico, annocorso, autori, codiceisbn, codicescuola, combinazione,
         consigliato, daacquist, disciplina, editore, nuovaadoz, prezzo, sezioneanno,
         sottotitolo, tipogradoscuola, titolo, volume)
      SELECT id, '202526', "ANNOCORSO", "AUTORI", "CODICEISBN", "CODICESCUOLA", "COMBINAZIONE",
             "CONSIGLIATO", "DAACQUIST", "DISCIPLINA", "EDITORE", "NUOVAADOZ", "PREZZO",
             "SEZIONEANNO", "SOTTOTITOLO", "TIPOGRADOSCUOLA", "TITOLO", "VOLUME"
      FROM import_adozioni
    SQL
    say "202526: #{select_value("SELECT count(*) FROM miur_adozioni_202526")} righe da import_adozioni"

    execute "TRUNCATE miur_scuole_202627"
    execute(<<~SQL)
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
    say "202627 scuole: #{select_value("SELECT count(*) FROM miur_scuole_202627")} righe da new_scuole"

    %w[miur_adozioni miur_scuole].each do |t|
      max = select_value("SELECT COALESCE(MAX(id), 1) FROM #{t}")
      execute "SELECT setval(pg_get_serial_sequence('#{t}', 'id'), #{max})"
      execute "ANALYZE #{t}"
    end
    say "Backfill completato"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # true solo se tutte e 4 esistono come TABELLE ordinarie (relkind='r'),
  # non come viste ponte (relkind='v') ne' assenti.
  def swing_tables_present?
    %w[old_adozioni import_adozioni new_adozioni new_scuole].all? do |t|
      select_value(
        "SELECT EXISTS (SELECT 1 FROM pg_class WHERE relname = '#{t}' AND relkind = 'r')"
      ).in?([true, "t", 1])
    end
  end
end
