class AddGradoToScuole < ActiveRecord::Migration[8.1]
  def up
    add_column :scuole, :grado, :string

    # Backfill grado from tipi_scuole lookup
    execute <<~SQL
      UPDATE scuole SET grado = tipi_scuole.grado
      FROM tipi_scuole WHERE scuole.tipo_scuola = tipi_scuole.tipo
    SQL

    add_index :scuole, [:account_id, :provincia, :grado], name: "index_scuole_on_account_provincia_grado"
  end

  def down
    remove_index :scuole, name: "index_scuole_on_account_provincia_grado"
    remove_column :scuole, :grado
  end
end
