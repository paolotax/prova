class MakeCategorieAccountScoped < ActiveRecord::Migration[8.1]
  def up
    # Guardia: il vincolo unico per account richiede nomi unici nell'account
    duplicati = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM (
        SELECT account_id, lower(trim(nome_categoria))
        FROM categorie
        GROUP BY account_id, lower(trim(nome_categoria))
        HAVING COUNT(*) > 1
      ) dup
    SQL
    raise "Ci sono #{duplicati} nomi categoria duplicati nello stesso account: mergiare prima di migrare" if duplicati.positive?

    remove_index :categorie, name: :index_categorie_on_user_id_and_nome_categoria
    remove_reference :categorie, :user, foreign_key: true

    add_index :categorie, "account_id, lower(trim(nome_categoria))",
              unique: true, name: :index_categorie_on_account_id_and_nome_categoria
  end

  def down
    remove_index :categorie, name: :index_categorie_on_account_id_and_nome_categoria
    add_reference :categorie, :user, foreign_key: true

    # Riassegna le categorie al primo utente dell'account
    execute <<~SQL
      UPDATE categorie
      SET user_id = (
        SELECT m.user_id FROM memberships m
        WHERE m.account_id = categorie.account_id
        ORDER BY m.created_at
        LIMIT 1
      )
    SQL

    add_index :categorie, "user_id, lower(trim(nome_categoria))",
              unique: true, name: :index_categorie_on_user_id_and_nome_categoria
  end
end
