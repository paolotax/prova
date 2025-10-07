class RepopulateCategorie < ActiveRecord::Migration[8.0]
  def up
    # Delete sconti that are not linked to users
    execute "DELETE FROM sconti WHERE user_id IS NULL"

    # First, assign user_id to existing categories based on the books that reference them
    execute(<<-SQL
      UPDATE categorie
      SET user_id = subquery.user_id
      FROM (
        SELECT DISTINCT categorie.id as categoria_id, libri.user_id
        FROM categorie
        INNER JOIN libri ON libri.categoria_id = categorie.id
        WHERE categorie.user_id IS NULL
      ) AS subquery
      WHERE categorie.id = subquery.categoria_id
    SQL
    )

    # Delete any remaining categories without user_id (not referenced by any libro)
    execute "DELETE FROM categorie WHERE user_id IS NULL"

    # Now create new categories from libri.collana for each user
    # Only if they don't already exist
    distinct_collane = execute(<<-SQL
      SELECT DISTINCT libri.user_id, libri.collana
      FROM libri
      LEFT JOIN categorie ON categorie.user_id = libri.user_id
        AND categorie.nome_categoria = libri.collana
      WHERE libri.collana IS NOT NULL
        AND libri.collana != ''
        AND categorie.id IS NULL
      ORDER BY libri.user_id, libri.collana
    SQL
    )

    # Insert new categories for each user based on their book collections
    distinct_collane.each do |row|
      user_id = row['user_id']
      collana = row['collana']

      execute(<<-SQL
        INSERT INTO categorie (user_id, nome_categoria, created_at, updated_at)
        VALUES (#{user_id}, '#{collana.gsub("'", "''")}', NOW(), NOW())
      SQL
      )
    end

    # Update libri.categoria_id to match the user-specific categories based on collana
    execute(<<-SQL
      UPDATE libri
      SET categoria_id = categorie.id
      FROM categorie
      WHERE libri.user_id = categorie.user_id
        AND libri.collana = categorie.nome_categoria
        AND libri.collana IS NOT NULL
        AND libri.collana != ''
    SQL
    )
  end

  def down
    # This migration is not reversible because we're recreating data
    raise ActiveRecord::IrreversibleMigration
  end
end
