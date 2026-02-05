class AddCoordinatesAndPositionToScuole < ActiveRecord::Migration[8.1]
  def up
    add_column :scuole, :latitude, :float
    add_column :scuole, :longitude, :float
    add_column :scuole, :posizione, :integer, default: 0

    add_index :scuole, [:account_id, :posizione]

    # Backfill latitude/longitude da import_scuole
    execute <<-SQL
      UPDATE scuole
      SET latitude = import_scuole.latitude,
          longitude = import_scuole.longitude
      FROM import_scuole
      WHERE scuole.import_scuola_id = import_scuole.id
        AND import_scuole.latitude IS NOT NULL
    SQL

    # Backfill posizione da user_scuole (via membership per account)
    execute <<-SQL
      UPDATE scuole
      SET posizione = sub.position
      FROM (
        SELECT DISTINCT ON (m.account_id, us.import_scuola_id)
          m.account_id,
          us.import_scuola_id,
          us.position
        FROM user_scuole us
        INNER JOIN memberships m ON us.user_id = m.user_id
        WHERE us.position IS NOT NULL
        ORDER BY m.account_id, us.import_scuola_id, us.position
      ) sub
      WHERE scuole.account_id = sub.account_id
        AND scuole.import_scuola_id = sub.import_scuola_id
    SQL
  end

  def down
    remove_index :scuole, [:account_id, :posizione]
    remove_column :scuole, :latitude
    remove_column :scuole, :longitude
    remove_column :scuole, :posizione
  end
end
