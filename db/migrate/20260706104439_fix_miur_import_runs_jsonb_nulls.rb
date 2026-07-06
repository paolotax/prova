class FixMiurImportRunsJsonbNulls < ActiveRecord::Migration[8.1]
  def change
    change_column_null :miur_import_runs, :regioni_aggiornate, false
    change_column_null :miur_import_runs, :regioni_stale, false
    change_column_null :miur_import_runs, :regioni_fallite, false
  end
end
