class BackfillDirezioniWithSql < ActiveRecord::Migration[8.1]
  def up
    # Passo 1: crea le scuole-direzione mancanti (istituti comprensivi)
    execute <<~SQL
      INSERT INTO scuole (id, account_id, import_scuola_id, codice_ministeriale, denominazione,
                          indirizzo, cap, comune, provincia, regione, tipo_scuola, email, pec,
                          grado, latitude, longitude, stato, posizione, priorita, created_at, updated_at)
      SELECT DISTINCT ON (s.account_id, idir."CODICESCUOLA")
        gen_random_uuid(),
        s.account_id,
        idir.id,
        idir."CODICESCUOLA",
        idir."DENOMINAZIONESCUOLA",
        idir."INDIRIZZOSCUOLA",
        idir."CAPSCUOLA",
        idir."DESCRIZIONECOMUNE",
        idir."PROVINCIA",
        idir."REGIONE",
        idir."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
        idir."INDIRIZZOEMAILSCUOLA",
        idir."INDIRIZZOPECSCUOLA",
        ts.grado,
        idir.latitude,
        idir.longitude,
        'attiva',
        0,
        0,
        NOW(),
        NOW()
      FROM scuole s
      JOIN import_scuole ip ON ip.id = s.import_scuola_id
      JOIN import_scuole idir ON idir."CODICESCUOLA" = ip."CODICEISTITUTORIFERIMENTO"
      LEFT JOIN tipi_scuole ts ON ts.tipo = idir."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
      WHERE s.direzione_id IS NULL
        AND ip."CODICEISTITUTORIFERIMENTO" IS NOT NULL
        AND ip."CODICEISTITUTORIFERIMENTO" != ''
        AND ip."CODICEISTITUTORIFERIMENTO" != ip."CODICESCUOLA"
        AND NOT EXISTS (
          SELECT 1 FROM scuole d
          WHERE d.account_id = s.account_id
          AND d.codice_ministeriale = ip."CODICEISTITUTORIFERIMENTO"
        )
    SQL

    # Passo 2: collega ogni plesso alla sua direzione
    execute <<~SQL
      UPDATE scuole
      SET direzione_id = direzioni.id
      FROM import_scuole,
           scuole AS direzioni
      WHERE scuole.direzione_id IS NULL
        AND scuole.import_scuola_id = import_scuole.id
        AND import_scuole."CODICEISTITUTORIFERIMENTO" IS NOT NULL
        AND import_scuole."CODICEISTITUTORIFERIMENTO" != ''
        AND import_scuole."CODICEISTITUTORIFERIMENTO" != import_scuole."CODICESCUOLA"
        AND direzioni.account_id = scuole.account_id
        AND direzioni.codice_ministeriale = import_scuole."CODICEISTITUTORIFERIMENTO"
    SQL
  end

  def down
    # noop
  end
end
