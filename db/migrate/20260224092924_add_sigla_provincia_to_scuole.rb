class AddSiglaProvinciaToScuole < ActiveRecord::Migration[8.1]
  def up
    add_column :scuole, :sigla_provincia, :string, limit: 2

    execute <<~SQL
      UPDATE scuole
      SET sigla_provincia = z.sigla
      FROM (SELECT DISTINCT provincia, sigla FROM zone) z
      WHERE scuole.provincia = z.provincia
    SQL
  end

  def down
    remove_column :scuole, :sigla_provincia
  end
end
