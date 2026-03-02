class BackfillGiroDateRangesFromTappe < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE giri
      SET iniziato_il = sub.min_data,
          finito_il = sub.max_data
      FROM (
        SELECT tappa_giri.giro_id,
               MIN(tappe.data_tappa) AS min_data,
               MAX(tappe.data_tappa) AS max_data
        FROM tappe
        INNER JOIN tappa_giri ON tappa_giri.tappa_id = tappe.id
        WHERE tappe.data_tappa IS NOT NULL
        GROUP BY tappa_giri.giro_id
      ) sub
      WHERE giri.id = sub.giro_id
        AND giri.iniziato_il IS NULL
        AND giri.finito_il IS NULL
    SQL
  end

  def down
    # no-op: cannot reliably revert backfill
  end
end
