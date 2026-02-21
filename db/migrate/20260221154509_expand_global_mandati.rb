class ExpandGlobalMandati < ActiveRecord::Migration[8.1]
  def up
    # Espande mandati con provincia/grado NULL in mandati specifici per ogni zona attiva
    # 1. Inserisce nuovi mandati specifici per ogni combinazione zona attiva
    execute <<~SQL
      INSERT INTO mandati (id, account_id, editore_id, provincia, grado, disdetta, sezioni_count, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        m.account_id,
        m.editore_id,
        az.provincia,
        az.grado,
        m.disdetta,
        0,
        NOW(),
        NOW()
      FROM mandati m
      JOIN account_zone az ON az.account_id = m.account_id AND az.stato = 'attiva'
      WHERE (m.provincia IS NULL OR m.grado IS NULL)
        AND (m.provincia IS NULL OR m.provincia = az.provincia)
        AND (m.grado IS NULL OR m.grado = az.grado)
      ON CONFLICT (account_id, editore_id, provincia, grado, anno_scolastico) DO NOTHING
    SQL

    # 2. Elimina i mandati globali (con NULL)
    execute <<~SQL
      DELETE FROM mandati WHERE provincia IS NULL OR grado IS NULL
    SQL
  end

  def down
    # Non reversibile
  end
end
