class AddAccountToRemainingModels < ActiveRecord::Migration[8.0]
  def up
    # Add account_id to categorie
    add_reference :categorie, :account, type: :uuid, foreign_key: true
    execute <<-SQL
      UPDATE categorie
      SET account_id = (
        SELECT m.account_id FROM memberships m
        WHERE m.user_id = categorie.user_id
        ORDER BY m.created_at LIMIT 1
      )
    SQL
    change_column_null :categorie, :account_id, false

    # Add account_id to giri
    add_reference :giri, :account, type: :uuid, foreign_key: true
    execute <<-SQL
      UPDATE giri
      SET account_id = (
        SELECT m.account_id FROM memberships m
        WHERE m.user_id = giri.user_id
        ORDER BY m.created_at LIMIT 1
      )
    SQL
    change_column_null :giri, :account_id, false

    # Add account_id to tappe
    add_reference :tappe, :account, type: :uuid, foreign_key: true
    execute <<-SQL
      UPDATE tappe
      SET account_id = (
        SELECT m.account_id FROM memberships m
        WHERE m.user_id = tappe.user_id
        ORDER BY m.created_at LIMIT 1
      )
    SQL
    change_column_null :tappe, :account_id, false

    # Add account_id to sconti
    add_reference :sconti, :account, type: :uuid, foreign_key: true
    execute <<-SQL
      UPDATE sconti
      SET account_id = (
        SELECT m.account_id FROM memberships m
        WHERE m.user_id = sconti.user_id
        ORDER BY m.created_at LIMIT 1
      )
    SQL
    change_column_null :sconti, :account_id, false

    # Add account_id to chats
    add_reference :chats, :account, type: :uuid, foreign_key: true
    execute <<-SQL
      UPDATE chats
      SET account_id = (
        SELECT m.account_id FROM memberships m
        WHERE m.user_id = chats.user_id
        ORDER BY m.created_at LIMIT 1
      )
    SQL
    change_column_null :chats, :account_id, false
  end

  def down
    remove_reference :categorie, :account
    remove_reference :giri, :account
    remove_reference :tappe, :account
    remove_reference :sconti, :account
    remove_reference :chats, :account
  end
end
