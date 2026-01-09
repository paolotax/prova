class RemoveDeviseColumnsFromUsers < ActiveRecord::Migration[8.0]
  def change
    # Remove Devise authentication columns
    remove_column :users, :encrypted_password, :string, default: "", null: false
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_sent_at, :datetime
    remove_column :users, :remember_created_at, :datetime

    # Remove Devise confirmable columns
    remove_column :users, :confirmation_token, :string
    remove_column :users, :confirmed_at, :datetime
    remove_column :users, :confirmation_sent_at, :datetime
    remove_column :users, :unconfirmed_email, :string

    # Remove associated indexes (if they exist)
    # These are handled automatically by remove_column
  end
end
