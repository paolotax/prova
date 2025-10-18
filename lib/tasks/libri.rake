namespace :libri do
  desc "Ricalcola adozioni_count per i libri"
  desc "Conta il numero totale di sezioni (import_adozioni) nelle scuole dell'utente per codice_isbn"
  desc "Esempi:"
  desc "  rails libri:ricalcola_adozioni_count                    # Ricalcola per tutti gli utenti"
  desc "  rails libri:ricalcola_adozioni_count[123]               # Ricalcola solo per user_id=123"
  task :ricalcola_adozioni_count, [:user_id] => :environment do |t, args|
    user_id = args[:user_id]

    if user_id.present?
      user = User.find_by(id: user_id)
      unless user
        puts "Errore: user con id #{user_id} non trovato"
        exit 1
      end

      puts "Ricalcolo adozioni_count per user #{user.email} (ID: #{user_id})..."

      # Reset a 0 per i libri dell'utente
      Libro.where(user_id: user_id).update_all(adozioni_count: 0)

      # Ricalcola contando le import_adozioni nelle scuole dell'utente
      sql = <<-SQL
        UPDATE libri
        SET adozioni_count = (
          SELECT COUNT(*)
          FROM import_adozioni ia
          INNER JOIN import_scuole isc ON ia."CODICESCUOLA" = isc."CODICESCUOLA"
          INNER JOIN user_scuole us ON isc.id = us.import_scuola_id
          WHERE ia."CODICEISBN" = libri.codice_isbn AND ia."DAACQUIST" = 'Si'
            AND us.user_id = #{user_id}
        )
        WHERE libri.user_id = #{user_id}
      SQL

      ActiveRecord::Base.connection.execute(sql)

      total = Libro.where(user_id: user_id).sum(:adozioni_count)
      puts "Ricalcolo completato! Totale adozioni: #{total}"
    else
      puts "Ricalcolo adozioni_count per tutti gli utenti..."

      User.find_each do |user|
        print "User #{user.email} (ID: #{user.id})... "

        # Reset a 0
        Libro.where(user_id: user.id).update_all(adozioni_count: 0)

        # Ricalcola
        sql = <<-SQL
          UPDATE libri
          SET adozioni_count = (
            SELECT COUNT(*)
            FROM import_adozioni ia
            INNER JOIN import_scuole isc ON ia."CODICESCUOLA" = isc."CODICESCUOLA"
            INNER JOIN user_scuole us ON isc.id = us.import_scuola_id
            WHERE ia."CODICEISBN" = libri.codice_isbn AND ia."DAACQUIST" = 'Si'
              AND us.user_id = #{user.id}
          )
          WHERE libri.user_id = #{user.id}
        SQL

        ActiveRecord::Base.connection.execute(sql)

        total = Libro.where(user_id: user.id).sum(:adozioni_count)
        puts "#{total} adozioni"
      end

      puts "Ricalcolo completato per tutti gli utenti!"
    end
  end

  desc "Aggiorna il prezzo_suggerito per i libri con sconto specificato (default 10%)"
  desc "Esempi:"
  desc "  rails libri:aggiorna_prezzo_suggerito                    # Aggiorna tutti gli utenti con sconto 10%"
  desc "  rails libri:aggiorna_prezzo_suggerito[123]               # Aggiorna user_id=123 con sconto 10%"
  desc "  rails libri:aggiorna_prezzo_suggerito[123,15]            # Aggiorna user_id=123 con sconto 15%"
  desc "  rails libri:aggiorna_prezzo_suggerito['',20]             # Aggiorna tutti gli utenti con sconto 20%"
  task :aggiorna_prezzo_suggerito, [:user_id, :sconto] => :environment do |t, args|
    user_id = args[:user_id]
    sconto = args[:sconto]&.to_f || 10.0
    moltiplicatore = (100.0 - sconto) / 100.0

    if user_id.present?
      user = User.find_by(id: user_id)
      unless user
        puts "Errore: user con id #{user_id} non trovato"
        exit 1
      end

      puts "Aggiornamento prezzo_suggerito per user #{user.email} (ID: #{user_id}) con sconto #{sconto}%..."

      sql = <<-SQL
        UPDATE libri
        SET prezzo_suggerito_cents = CEIL((prezzo_in_cents * #{moltiplicatore}) / 10.0) * 10
        WHERE prezzo_in_cents > 0 AND user_id = #{user_id}
      SQL

      result = ActiveRecord::Base.connection.execute(sql)

      puts "Prezzo suggerito aggiornato con successo per user #{user.email} con sconto #{sconto}%!"
    else
      puts "Aggiornamento prezzo_suggerito per tutti gli utenti con sconto #{sconto}%..."

      sql = <<-SQL
        UPDATE libri
        SET prezzo_suggerito_cents = CEIL((prezzo_in_cents * #{moltiplicatore}) / 10.0) * 10
        WHERE prezzo_in_cents > 0
      SQL

      result = ActiveRecord::Base.connection.execute(sql)

      puts "Prezzo suggerito aggiornato con successo per tutti gli utenti con sconto #{sconto}%!"
    end
  end
end
