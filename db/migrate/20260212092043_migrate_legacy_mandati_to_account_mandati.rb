class MigrateLegacyMandatiToAccountMandati < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO mandati (id, account_id, editore_id, contratto, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        m.account_id,
        lm.editore_id,
        lm.contratto,
        lm.created_at,
        lm.updated_at
      FROM legacy_mandati lm
      INNER JOIN memberships m ON m.user_id = lm.user_id
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM mandati
      WHERE created_at IN (SELECT created_at FROM legacy_mandati)
    SQL
  end
end
