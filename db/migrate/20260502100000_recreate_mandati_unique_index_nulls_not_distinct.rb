class RecreateMandatiUniqueIndexNullsNotDistinct < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_mandati_unique_nnd
      ON mandati (account_id, editore_id, provincia, grado, anno_scolastico, area)
      NULLS NOT DISTINCT
    SQL

    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_mandati_unique"
    execute "ALTER INDEX idx_mandati_unique_nnd RENAME TO idx_mandati_unique"
  end

  def down
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_mandati_unique_old
      ON mandati (account_id, editore_id, provincia, grado, anno_scolastico, area)
    SQL

    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_mandati_unique"
    execute "ALTER INDEX idx_mandati_unique_old RENAME TO idx_mandati_unique"
  end
end
