namespace :zone do
  desc "Rebuild adozioni per un account (backfill direzioni + update mie adozioni)"
  task :rebuild, [:account_id] => :environment do |_, args|
    account = Account.find(args.fetch(:account_id))
    puts "Rebuilding adozioni for #{account.name} (#{account.id})..."
    RebuildAccountAdozioniJob.perform_now(account)
    puts "Done."
  end
end
