class AddAccountToAziende < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add account_id column (nullable initially)
    add_reference :aziende, :account, null: true, type: :uuid, index: true

    # Step 2: Backfill account_id from user's primary membership
    execute <<-SQL.squish
      UPDATE aziende
      SET account_id = (
        SELECT m.account_id
        FROM memberships m
        WHERE m.user_id = aziende.user_id
        ORDER BY m.created_at ASC
        LIMIT 1
      )
    SQL

    # Step 3: For any aziende without account (user has no memberships),
    # create an account for them
    execute <<-SQL.squish
      INSERT INTO accounts (id, name, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        a.ragione_sociale,
        a.created_at,
        a.updated_at
      FROM aziende a
      WHERE a.account_id IS NULL
    SQL

    # Step 4: Link orphan aziende to their new accounts
    execute <<-SQL.squish
      UPDATE aziende
      SET account_id = (
        SELECT acc.id
        FROM accounts acc
        WHERE acc.name = aziende.ragione_sociale
        AND aziende.account_id IS NULL
        LIMIT 1
      )
      WHERE account_id IS NULL
    SQL

    # Step 5: Make account_id not nullable
    change_column_null :aziende, :account_id, false

    # Step 6: Make the existing index unique (one azienda per account)
    remove_index :aziende, :account_id
    add_index :aziende, :account_id, unique: true

    # Log migration result
    count = execute("SELECT COUNT(*) FROM aziende WHERE account_id IS NOT NULL").first["count"]
    say "Migrated #{count} aziende to accounts"
  end

  def down
    remove_index :aziende, :account_id, if_exists: true
    remove_reference :aziende, :account
  end
end
