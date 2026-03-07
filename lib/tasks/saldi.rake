namespace :saldi do
  desc "Ricalcola tutti i saldi per clienti e scuole"
  task ricalcola: :environment do
    Account.find_each do |account|
      Current.set(account: account) do
        print "Account #{account.id}: "

        count = 0
        account.clienti.find_each do |cliente|
          cliente.ricalcola_saldo!
          count += 1
        end
        print "#{count} clienti, "

        count = 0
        account.scuole.find_each do |scuola|
          scuola.ricalcola_saldo!
          count += 1
        end
        puts "#{count} scuole"
      end
    end
  end
end
