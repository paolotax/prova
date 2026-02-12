class FixAccountZoneFromUserScuole < ActiveRecord::Migration[8.1]
  def up
    # Remove placeholder account_zone records
    execute "DELETE FROM account_zone"

    # Create account_zone from user_scuole grouped by provincia/grado
    # Use subquery for regione to avoid join-multiplication with zone table
    execute <<~SQL
      INSERT INTO account_zone (id, account_id, provincia, grado, regione, anno_scolastico, scuole_count, stato, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        sub.account_id,
        sub.provincia,
        sub.grado,
        (SELECT z.regione FROM zone z WHERE z.provincia = sub.provincia LIMIT 1),
        '2025/2026',
        sub.cnt,
        'attiva',
        NOW(),
        NOW()
      FROM (
        SELECT
          m.account_id,
          i."PROVINCIA" AS provincia,
          ts.grado,
          count(*) AS cnt
        FROM user_scuole us
        JOIN import_scuole i ON i.id = us.import_scuola_id
        JOIN memberships m ON m.user_id = us.user_id
        JOIN tipi_scuole ts ON ts.tipo = i."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
        GROUP BY m.account_id, i."PROVINCIA", ts.grado
      ) sub
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM account_zone"
  end
end
