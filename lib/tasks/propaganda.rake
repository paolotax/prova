namespace :propaganda do
  desc "Crea una Propaganda per un utente e le assegna i giri indicati. " \
       "Uso: bin/rails 'propaganda:crea[3, Propaganda 26, 50 60 61]' (user_id, nome, giro_ids spazio-separati)"
  task :crea, [:user_id, :nome, :giro_ids] => :environment do |_t, args|
    user = User.find(args[:user_id])
    account = user.accounts.first
    Current.account = account
    Current.user = user

    nome = args[:nome].presence || "Propaganda #{Date.current.year}"
    giro_ids = args[:giro_ids].to_s.split(/\s+/).map(&:to_i)

    propaganda = user.propagande.where(nome: nome).first_or_create!(account: account)
    aggiornati = Giro.where(id: giro_ids, user_id: user.id).update_all(propaganda_id: propaganda.id)

    puts "Propaganda \"#{propaganda.nome}\" (#{propaganda.id})"
    propaganda.giri.reload.each { |g| puts "  - #{g.titolo}" }
    puts "Giri assegnati: #{aggiornati}"
  end
end
