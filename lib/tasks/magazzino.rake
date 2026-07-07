namespace :magazzino do
  desc "Ricalcola tutte le giacenze per ogni account (backfill/recovery)"
  task ricalcola_giacenze: :environment do
    Account.find_each do |account|
      Giacenza.ricalcola_tutte!(account)
      puts "Account #{account.id}: #{Giacenza.where(account_id: account.id).count} giacenze"
    end
  end
end
