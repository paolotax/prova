namespace :accounts do
  desc "Crea Account per ogni User esistente e backfill appunti"
  task setup: :environment do
    ActiveRecord::Base.transaction do
      User.find_each do |user|
        # Salta se l'utente ha già un account
        if user.accounts.any?
          puts "User #{user.name} ha già un account, skip..."
          next
        end

        # Crea account per ogni user (inizialmente 1:1)
        account = Account.create!(name: "Account di #{user.name}")
        Membership.create!(user: user, account: account, role: :owner)

        # Backfill appunti di questo user
        count = user.appunti.where(account_id: nil).update_all(account_id: account.id)

        puts "Created account for #{user.name}: #{account.id} (#{count} appunti migrati)"
      end
    end

    puts "\n✅ Setup completato!"
    puts "Account totali: #{Account.count}"
    puts "Membership totali: #{Membership.count}"
    puts "Appunti senza account: #{Appunto.where(account_id: nil).count}"
  end

  desc "Verifica che tutti gli appunti abbiano un account"
  task verify: :environment do
    orphans = Appunto.where(account_id: nil).count
    if orphans.zero?
      puts "✅ Tutti gli appunti hanno un account_id"
    else
      puts "❌ #{orphans} appunti senza account_id"
    end
  end
end
