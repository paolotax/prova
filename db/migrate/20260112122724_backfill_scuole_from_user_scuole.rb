class BackfillScuoleFromUserScuole < ActiveRecord::Migration[8.0]
  def up
    # Per ogni user_scuola, crea una Scuola nel primary account dell'utente
    execute <<-SQL
      INSERT INTO scuole (
        id, account_id, import_scuola_id, codice_ministeriale, denominazione,
        indirizzo, cap, comune, provincia, regione, tipo_scuola,
        email, pec, telefono, stato, priorita, created_at, updated_at
      )
      SELECT DISTINCT ON (m.account_id, i."CODICESCUOLA")
        gen_random_uuid(),
        m.account_id,
        i.id,
        i."CODICESCUOLA",
        i."DENOMINAZIONESCUOLA",
        i."INDIRIZZOSCUOLA",
        i."CAPSCUOLA",
        i."DESCRIZIONECOMUNE",
        i."PROVINCIA",
        i."REGIONE",
        i."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
        i."INDIRIZZOEMAILSCUOLA",
        i."INDIRIZZOPECSCUOLA",
        NULL,
        'attiva',
        0,
        NOW(),
        NOW()
      FROM user_scuole us
      INNER JOIN import_scuole i ON us.import_scuola_id = i.id
      INNER JOIN memberships m ON us.user_id = m.user_id
      WHERE m.account_id IS NOT NULL
      ORDER BY m.account_id, i."CODICESCUOLA", m.created_at
    SQL
  end

  def down
    execute "DELETE FROM scuole"
  end
end
