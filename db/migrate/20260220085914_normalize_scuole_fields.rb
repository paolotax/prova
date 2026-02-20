class NormalizeScuoleFields < ActiveRecord::Migration[8.1]
  def up
    # Normalizza tipo_scuola a UPPERCASE
    execute <<~SQL
      UPDATE scuole SET tipo_scuola = UPPER(tipo_scuola) WHERE tipo_scuola IS NOT NULL AND tipo_scuola != UPPER(tipo_scuola)
    SQL

    # Normalizza regione a UPPERCASE
    execute <<~SQL
      UPDATE scuole SET regione = UPPER(regione) WHERE regione IS NOT NULL AND regione != UPPER(regione)
    SQL

    # Pulisci PEC "Non Disponibile"
    execute <<~SQL
      UPDATE scuole SET pec = NULL WHERE LOWER(pec) LIKE '%non disponibil%'
    SQL
  end

  def down
    # Non reversibile
  end
end
