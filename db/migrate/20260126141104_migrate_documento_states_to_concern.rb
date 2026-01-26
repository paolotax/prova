class MigrateDocumentoStatesToConcern < ActiveRecord::Migration[8.1]
  def up
    # Migra pagamenti da documenti con pagato_il popolato
    execute <<-SQL
      INSERT INTO pagamenti (id, pagabile_type, pagabile_id, pagato_il, tipo_pagamento, account_id, user_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Documento',
        d.id::text,
        d.pagato_il,
        CASE d.tipo_pagamento
          WHEN 0 THEN 'contanti'
          WHEN 1 THEN 'assegno'
          WHEN 2 THEN 'bonifico'
          WHEN 3 THEN 'bancomat'
          WHEN 4 THEN 'carta_di_credito'
          WHEN 5 THEN 'paypal'
          WHEN 6 THEN 'satispay'
          WHEN 7 THEN 'cedole'
          ELSE NULL
        END,
        d.account_id,
        d.user_id,
        COALESCE(d.pagato_il, NOW()),
        NOW()
      FROM documenti d
      WHERE d.pagato_il IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM pagamenti p
          WHERE p.pagabile_type = 'Documento' AND p.pagabile_id = d.id::text
        )
    SQL

    # Migra consegne da documenti con consegnato_il popolato
    execute <<-SQL
      INSERT INTO consegne (id, consegnabile_type, consegnabile_id, consegnato_il, account_id, user_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Documento',
        d.id::text,
        d.consegnato_il,
        d.account_id,
        d.user_id,
        COALESCE(d.consegnato_il::timestamp, NOW()),
        NOW()
      FROM documenti d
      WHERE d.consegnato_il IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM consegne c
          WHERE c.consegnabile_type = 'Documento' AND c.consegnabile_id = d.id::text
        )
    SQL

    # Auto-close documenti che sono sia pagati che consegnati
    execute <<-SQL
      INSERT INTO closures (id, closeable_type, closeable_id, account_id, user_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Documento',
        d.id::text,
        d.account_id,
        d.user_id,
        GREATEST(COALESCE(d.pagato_il, NOW()), COALESCE(d.consegnato_il::timestamp, NOW())),
        NOW()
      FROM documenti d
      WHERE d.pagato_il IS NOT NULL
        AND d.consegnato_il IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM closures cl
          WHERE cl.closeable_type = 'Documento' AND cl.closeable_id = d.id::text
        )
    SQL
  end

  def down
    execute "DELETE FROM closures WHERE closeable_type = 'Documento'"
    execute "DELETE FROM consegne WHERE consegnabile_type = 'Documento'"
    execute "DELETE FROM pagamenti WHERE pagabile_type = 'Documento'"
  end
end
