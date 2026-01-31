class FixDocumentiScuolaAccountMismatch < ActiveRecord::Migration[8.0]
  def up
    # Corregge i documenti che hanno una Scuola di un account diverso
    # Trova la scuola corretta basandosi su import_scuola_id e account_id del documento
    execute <<-SQL
      UPDATE documenti
      SET clientable_id = scuole_corrette.id
      FROM documenti AS d
      INNER JOIN scuole AS scuole_sbagliate ON d.clientable_id = scuole_sbagliate.id
      INNER JOIN scuole AS scuole_corrette ON scuole_corrette.import_scuola_id = scuole_sbagliate.import_scuola_id
                                           AND scuole_corrette.account_id = d.account_id
      WHERE documenti.id = d.id
        AND d.clientable_type = 'Scuola'
        AND scuole_sbagliate.account_id != d.account_id;
    SQL
  end

  def down
    # Non reversibile - i dati originali erano già errati
    raise ActiveRecord::IrreversibleMigration
  end
end
