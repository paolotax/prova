class DropAdozioni < ActiveRecord::Migration[8.0]
  def up
    drop_table :adozioni
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
