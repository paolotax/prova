namespace :scuole do
  desc "Ricalcola classi_count, adozioni_count e mie_adozioni_count per tutte le scuole"
  task ricalcola_counters: :environment do
    Account.find_each do |account|
      print "Account #{account.id}... "
      UpdateScuoleCountersJob.perform_now(account)
      puts "done"
    end
  end
end
