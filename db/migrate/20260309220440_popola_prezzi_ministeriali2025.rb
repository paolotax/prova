class PopolaPrezziMinisteriali2025 < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO prezzi_ministeriali (id, anno_scolastico, classe, disciplina, prezzo_cents, created_at, updated_at)
      SELECT gen_random_uuid(), '2025/2026', sub.classe, sub.disciplina, sub.prezzo_cents, NOW(), NOW()
      FROM (
        WITH prezzi AS (
          SELECT "ANNOCORSO" as classe,
                 "DISCIPLINA" as disciplina,
                 ROUND(REPLACE("PREZZO", ',', '.')::numeric * 100)::integer as prezzo_cents,
                 COUNT(*) as freq
          FROM import_adozioni
          WHERE "TIPOGRADOSCUOLA" = 'EE'
            AND "PREZZO" IS NOT NULL
            AND "PREZZO" != ''
            AND REPLACE("PREZZO", ',', '.') ~ '^\\d+(\\.\\d+)?$'
          GROUP BY "ANNOCORSO", "DISCIPLINA", ROUND(REPLACE("PREZZO", ',', '.')::numeric * 100)::integer
        ),
        ranked AS (
          SELECT classe, disciplina, prezzo_cents, freq,
                 ROW_NUMBER() OVER (PARTITION BY classe, disciplina ORDER BY freq DESC) as rn,
                 SUM(freq) OVER (PARTITION BY classe, disciplina) as totale
          FROM prezzi
        )
        SELECT classe, disciplina, prezzo_cents
        FROM ranked
        WHERE rn = 1
          AND totale > 100
          AND freq::float / totale::float > 0.9
      ) sub
      ON CONFLICT (anno_scolastico, classe, disciplina) DO UPDATE
        SET prezzo_cents = EXCLUDED.prezzo_cents, updated_at = NOW()
    SQL
  end

  def down
    execute "DELETE FROM prezzi_ministeriali WHERE anno_scolastico = '2025/2026'"
  end
end
