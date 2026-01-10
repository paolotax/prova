class ChangeUserIdNullableOnAziende < ActiveRecord::Migration[8.0]
  def up
    # Make user_id nullable since Azienda now belongs to Account, not User
    change_column_null :aziende, :user_id, true

    # Remove foreign key constraint if exists
    if foreign_key_exists?(:aziende, :users)
      remove_foreign_key :aziende, :users
    end
  end

  def down
    # Restore NOT NULL constraint (only if all rows have user_id)
    change_column_null :aziende, :user_id, false
  end
end
