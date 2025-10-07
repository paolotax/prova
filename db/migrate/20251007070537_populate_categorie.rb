class PopulateCategorie < ActiveRecord::Migration[8.0]
  def up
    # Prima normalizza le categorie in libri: tutto minuscolo
    execute <<-SQL
      UPDATE libri
      SET categoria = LOWER(TRIM(categoria))
      WHERE categoria IS NOT NULL AND categoria != '';
    SQL

    # Inserisce una categoria di default per valori blank/nil
    execute <<-SQL
      INSERT INTO categorie (nome_categoria, descrizione, created_at, updated_at)
      VALUES ('non classificato', 'Categoria di default per libri senza categoria', NOW(), NOW())
      ON CONFLICT (nome_categoria) DO NOTHING;
    SQL

    # Estrae tutte le categorie uniche dal campo categoria della tabella libri
    # e le inserisce nella tabella categorie (già normalizzate in minuscolo)
    execute <<-SQL
      INSERT INTO categorie (nome_categoria, created_at, updated_at)
      SELECT DISTINCT LOWER(TRIM(categoria)), NOW(), NOW()
      FROM libri
      WHERE categoria IS NOT NULL AND categoria != ''
      ORDER BY LOWER(TRIM(categoria))
      ON CONFLICT (nome_categoria) DO NOTHING;
    SQL
  end

  def down
    # In caso di rollback, svuota la tabella categorie
    execute "DELETE FROM categorie;"
  end
end
