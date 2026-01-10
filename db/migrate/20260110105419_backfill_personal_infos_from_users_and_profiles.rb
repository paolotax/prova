class BackfillPersonalInfosFromUsersAndProfiles < ActiveRecord::Migration[8.0]
  def up
    # Backfill PersonalInfo from User and Profile data
    execute <<-SQL.squish
      INSERT INTO personal_infos (id, user_id, nome, cognome, cellulare, email_personale, navigator, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        users.id,
        COALESCE(profiles.nome, split_part(users.name, ' ', 1), users.name),
        COALESCE(profiles.cognome, NULLIF(split_part(users.name, ' ', 2), ''), 'N/A'),
        profiles.cellulare,
        profiles.email,
        users.navigator,
        COALESCE(profiles.created_at, users.created_at),
        COALESCE(profiles.updated_at, users.updated_at)
      FROM users
      LEFT JOIN profiles ON profiles.user_id = users.id
      WHERE NOT EXISTS (
        SELECT 1 FROM personal_infos WHERE personal_infos.user_id = users.id
      )
    SQL

    # Log the count of migrated records
    count = execute("SELECT COUNT(*) FROM personal_infos").first["count"]
    say "Migrated #{count} personal_info records"
  end

  def down
    # Remove all personal_infos that were created from this migration
    # (only those that match user data pattern)
    execute <<-SQL.squish
      DELETE FROM personal_infos
      WHERE user_id IN (SELECT id FROM users)
    SQL
  end
end
