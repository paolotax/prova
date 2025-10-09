namespace :libri do
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
