class BackfillAccountIdOnAppunti < ActiveRecord::Migration[8.0]
  def up
    # Backfill account_id from user's primary membership
    execute <<-SQL
      UPDATE appunti
      SET account_id = (
        SELECT m.account_id FROM memberships m
        WHERE m.user_id = appunti.user_id
        ORDER BY m.created_at
        LIMIT 1
      )
      WHERE account_id IS NULL;
    SQL
  end

  def down
    # No rollback needed
  end
end
