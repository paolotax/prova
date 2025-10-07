class AddUserIdToCategorie < ActiveRecord::Migration[8.0]
  def change
    # Remove unique index on nome_categoria since categories will be per-user
    remove_index :categorie, :nome_categoria, if_exists: true

    # Add user_id column (nullable first to handle existing data)
    add_reference :categorie, :user, null: true, foreign_key: true

    # Add composite unique index for user_id + nome_categoria
    add_index :categorie, [:user_id, :nome_categoria], unique: true
  end
end
