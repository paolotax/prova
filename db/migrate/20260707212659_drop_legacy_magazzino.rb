class DropLegacyMagazzino < ActiveRecord::Migration[8.1]
  def up
    # Ricreata a mano in 20260126141155, non più gestita da Scenic: drop diretto.
    # (tablefunc resta installata: la usano le query Blazer)
    execute "DROP VIEW IF EXISTS view_giacenze"

    remove_column :documenti, :status
    remove_column :documenti, :consegnato_il
    remove_column :documenti, :pagato_il
    remove_column :documenti, :tipo_pagamento
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
