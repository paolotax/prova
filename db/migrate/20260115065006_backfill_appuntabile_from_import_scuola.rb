class BackfillAppuntabileFromImportScuola < ActiveRecord::Migration[8.0]
  def up
    # Backfill appuntabile_type and appuntabile_id from import_scuola_id
    # Join appunti with scuole on import_scuola_id AND account_id
    execute <<-SQL
      UPDATE appunti
      SET appuntabile_type = 'Scuola',
          appuntabile_id = scuole.id
      FROM scuole
      WHERE appunti.import_scuola_id = scuole.import_scuola_id
        AND appunti.account_id = scuole.account_id
        AND appunti.import_scuola_id IS NOT NULL
    SQL
  end

  def down
    execute <<-SQL
      UPDATE appunti
      SET appuntabile_type = NULL,
          appuntabile_id = NULL
      WHERE appuntabile_type = 'Scuola'
    SQL
  end
end
