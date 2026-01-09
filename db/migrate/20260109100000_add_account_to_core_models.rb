# Migrazione sicura per aggiungere account_id ai modelli core
# Preserva tutti i dati esistenti e crea account per utenti che non ne hanno
class AddAccountToCoreModels < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Aggiungere colonne (nullable inizialmente)
    add_reference :documenti, :account, type: :uuid, null: true
    add_reference :clienti, :account, type: :uuid, null: true
    add_reference :libri, :account, type: :uuid, null: true

    # Step 2: Creare account per utenti che non ne hanno
    execute <<-SQL
      INSERT INTO accounts (id, name, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        users.name || ' Team',
        NOW(),
        NOW()
      FROM users
      WHERE NOT EXISTS (
        SELECT 1 FROM memberships WHERE memberships.user_id = users.id
      )
    SQL

    # Step 3: Creare membership per nuovi account
    execute <<-SQL
      INSERT INTO memberships (id, user_id, account_id, role, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        users.id,
        (SELECT id FROM accounts WHERE name = users.name || ' Team' ORDER BY created_at DESC LIMIT 1),
        2,
        NOW(),
        NOW()
      FROM users
      WHERE NOT EXISTS (
        SELECT 1 FROM memberships WHERE memberships.user_id = users.id
      )
    SQL

    # Step 4: Backfill documenti (PRESERVA TUTTI I DATI)
    execute <<-SQL
      UPDATE documenti
      SET account_id = (
        SELECT m.account_id
        FROM memberships m
        WHERE m.user_id = documenti.user_id
        ORDER BY m.role DESC, m.created_at ASC
        LIMIT 1
      )
      WHERE account_id IS NULL
    SQL

    # Step 5: Backfill clienti
    execute <<-SQL
      UPDATE clienti
      SET account_id = (
        SELECT m.account_id
        FROM memberships m
        WHERE m.user_id = clienti.user_id
        ORDER BY m.role DESC, m.created_at ASC
        LIMIT 1
      )
      WHERE account_id IS NULL
    SQL

    # Step 6: Backfill libri
    execute <<-SQL
      UPDATE libri
      SET account_id = (
        SELECT m.account_id
        FROM memberships m
        WHERE m.user_id = libri.user_id
        ORDER BY m.role DESC, m.created_at ASC
        LIMIT 1
      )
      WHERE account_id IS NULL
    SQL

    # Step 7: Verifica - NESSUN record deve avere account_id NULL
    orphan_docs = execute("SELECT COUNT(*) FROM documenti WHERE account_id IS NULL").first["count"]
    orphan_clients = execute("SELECT COUNT(*) FROM clienti WHERE account_id IS NULL").first["count"]
    orphan_books = execute("SELECT COUNT(*) FROM libri WHERE account_id IS NULL").first["count"]

    if orphan_docs.to_i > 0 || orphan_clients.to_i > 0 || orphan_books.to_i > 0
      raise "ERRORE: Trovati record orfani! docs=#{orphan_docs}, clients=#{orphan_clients}, books=#{orphan_books}. Rollback automatico."
    end

    # Step 8: Solo ora rendiamo NOT NULL
    change_column_null :documenti, :account_id, false
    change_column_null :clienti, :account_id, false
    change_column_null :libri, :account_id, false

    # Step 9: Indici per performance
    add_index :documenti, [:account_id, :created_at]
    add_index :clienti, [:account_id, :created_at]
    add_index :libri, [:account_id, :created_at]

    say "Migrazione completata con successo!"
    say "  Documenti migrati: #{execute('SELECT COUNT(*) FROM documenti').first['count']}"
    say "  Clienti migrati: #{execute('SELECT COUNT(*) FROM clienti').first['count']}"
    say "  Libri migrati: #{execute('SELECT COUNT(*) FROM libri').first['count']}"
  end

  def down
    remove_index :documenti, [:account_id, :created_at], if_exists: true
    remove_index :clienti, [:account_id, :created_at], if_exists: true
    remove_index :libri, [:account_id, :created_at], if_exists: true

    remove_reference :documenti, :account
    remove_reference :clienti, :account
    remove_reference :libri, :account

    say "Rollback completato. Le colonne account_id sono state rimosse."
    say "Nota: Gli account e membership creati automaticamente NON vengono rimossi."
  end
end
