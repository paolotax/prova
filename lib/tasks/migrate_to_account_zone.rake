namespace :multi_tenancy do
  desc "Migrate user zones to account zones"
  task migrate_zones: :environment do
    User.joins(:user_scuole).distinct.find_each do |user|
      account = user.accounts.first
      next unless account

      user.zone.each do |(regione, provincia, grado), _count|
        AccountZona.find_or_create_by!(
          account: account,
          provincia: provincia,
          grado: grado,
          anno_scolastico: "2024/2025"
        ) { |az| az.regione = regione }
        puts "  #{account.name}: #{provincia} #{grado}"
      end
    end
    puts "Done migrating zones!"
  end

  desc "Migrate user mandati to account mandati"
  task migrate_mandati: :environment do
    LegacyMandato.find_each do |legacy|
      account = legacy.user.accounts.first
      next unless account

      Mandato.find_or_create_by!(
        account: account,
        editore: legacy.editore,
        anno_scolastico: "2024/2025"
      ) { |m| m.contratto = legacy.contratto }
      puts "  #{account.name}: #{legacy.editore.editore}"
    end
    puts "Done migrating mandati!"
  end

  desc "Update mie adozioni for all accounts"
  task update_mie_adozioni: :environment do
    Account.find_each do |account|
      UpdateMieAdozioniJob.perform_later(account)
      puts "  Enqueued UpdateMieAdozioniJob for #{account.name}"
    end
    puts "Done!"
  end
end
