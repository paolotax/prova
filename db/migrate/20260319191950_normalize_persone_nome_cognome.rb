class NormalizePersoneNomeCognome < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE persone
      SET nome = initcap(lower(trim(regexp_replace(nome, '\\s+', ' ', 'g'))))
      WHERE nome IS NOT NULL;

      UPDATE persone
      SET cognome = initcap(lower(trim(regexp_replace(cognome, '\\s+', ' ', 'g'))))
      WHERE cognome IS NOT NULL;
    SQL
  end

  def down
    # irreversible
  end
end
