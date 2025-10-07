class AddUserIdToSconti < ActiveRecord::Migration[8.0]
  def up
    # Add user_id column (nullable first to handle existing data)
    add_reference :sconti, :user, null: true, foreign_key: true

    # Update existing unique index to include user_id
    remove_index :sconti, name: "index_sconti_unique", if_exists: true
    add_index :sconti, [:user_id, :scontabile_type, :scontabile_id, :categoria_id, :data_inizio, :tipo_sconto],
              unique: true, name: "index_sconti_unique"
  end

  def down
    # Remove the new unique index
    remove_index :sconti, name: "index_sconti_unique", if_exists: true

    # Restore original index
    add_index :sconti, [:scontabile_type, :scontabile_id, :categoria_id, :data_inizio, :tipo_sconto],
              unique: true, name: "index_sconti_unique"

    # Remove user_id column
    remove_reference :sconti, :user, foreign_key: true
  end
end
