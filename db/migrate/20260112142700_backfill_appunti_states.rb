class BackfillAppuntiStates < ActiveRecord::Migration[8.0]
  def up
    # Questa migration gira DOPO ConvertAppuntiToUuid
    # quindi appunti.id è già uuid

    # Mapping dai valori reali di STATO_APPUNTI agli State Records
    # 'in evidenza' → Goldness (priorità alta)
    # 'completato', 'archiviato' → Closure (chiuso)
    # 'in visione', 'da pagare' → Consegna (consegnato)
    #
    # Nota: escludiamo appunti con account_id NULL

    execute <<-SQL
      -- Goldness per appunti con stato = 'in evidenza' (priorità alta)
      INSERT INTO goldnesses (id, account_id, goldenable_type, goldenable_id, user_id, created_at, updated_at)
      SELECT gen_random_uuid(), account_id, 'Appunto', id, user_id, updated_at, NOW()
      FROM appunti
      WHERE stato = 'in evidenza' AND account_id IS NOT NULL;

      -- Closures per appunti con stato = 'completato' o 'archiviato'
      INSERT INTO closures (id, account_id, closeable_type, closeable_id, user_id, created_at, updated_at)
      SELECT gen_random_uuid(), account_id, 'Appunto', id, user_id, updated_at, NOW()
      FROM appunti
      WHERE stato IN ('completato', 'archiviato') AND account_id IS NOT NULL;

      -- Consegne per appunti con stato = 'in visione' o 'da pagare' (consegnati)
      INSERT INTO consegne (id, account_id, consegnabile_type, consegnabile_id, user_id, consegnato_il, created_at, updated_at)
      SELECT gen_random_uuid(), account_id, 'Appunto', id, user_id, updated_at, updated_at, NOW()
      FROM appunti
      WHERE stato IN ('in visione', 'da pagare') AND account_id IS NOT NULL;
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM goldnesses WHERE goldenable_type = 'Appunto';
      DELETE FROM closures WHERE closeable_type = 'Appunto';
      DELETE FROM consegne WHERE consegnabile_type = 'Appunto';
    SQL
  end
end
