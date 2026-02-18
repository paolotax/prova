class ChangeCategorieUniquIndexToCaseInsensitive < ActiveRecord::Migration[8.0]
  def up
    # Merge duplicate categories (case-insensitive) before adding the new index
    execute <<~SQL
      WITH duplicates AS (
        SELECT
          c1.id AS keep_id,
          c2.id AS merge_id
        FROM categorie c1
        JOIN categorie c2 ON c1.user_id = c2.user_id
          AND LOWER(TRIM(c1.nome_categoria)) = LOWER(TRIM(c2.nome_categoria))
          AND c1.id < c2.id
      )
      UPDATE libri
      SET categoria_id = duplicates.keep_id
      FROM duplicates
      WHERE libri.categoria_id = duplicates.merge_id;
    SQL

    execute <<~SQL
      WITH duplicates AS (
        SELECT
          c1.id AS keep_id,
          c2.id AS merge_id
        FROM categorie c1
        JOIN categorie c2 ON c1.user_id = c2.user_id
          AND LOWER(TRIM(c1.nome_categoria)) = LOWER(TRIM(c2.nome_categoria))
          AND c1.id < c2.id
      )
      UPDATE sconti
      SET categoria_id = duplicates.keep_id
      FROM duplicates
      WHERE sconti.categoria_id = duplicates.merge_id;
    SQL

    execute <<~SQL
      DELETE FROM categorie
      WHERE id IN (
        SELECT c2.id
        FROM categorie c1
        JOIN categorie c2 ON c1.user_id = c2.user_id
          AND LOWER(TRIM(c1.nome_categoria)) = LOWER(TRIM(c2.nome_categoria))
          AND c1.id < c2.id
      );
    SQL

    # Normalize all names to lowercase/stripped
    execute <<~SQL
      UPDATE categorie SET nome_categoria = LOWER(TRIM(nome_categoria));
    SQL

    # Replace old index with case-insensitive one
    remove_index :categorie, name: :index_categorie_on_user_id_and_nome_categoria
    add_index :categorie, "user_id, LOWER(TRIM(nome_categoria))",
              unique: true,
              name: :index_categorie_on_user_id_and_nome_categoria
  end

  def down
    remove_index :categorie, name: :index_categorie_on_user_id_and_nome_categoria
    add_index :categorie, [:user_id, :nome_categoria],
              unique: true,
              name: :index_categorie_on_user_id_and_nome_categoria
  end
end
