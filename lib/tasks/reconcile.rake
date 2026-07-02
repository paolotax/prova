namespace :reconcile do
  desc "Ricostruzione set-based classi/adozioni per un account (ACCOUNT_ID=... [PROVINCIA=BO] [ANNO=202627])"
  task adozioni: :environment do
    account = Account.find(ENV.fetch("ACCOUNT_ID"))
    prov = ENV["PROVINCIA"].presence
    anno = ENV["ANNO"].presence

    if prov && anno
      Adozione::Reconciler.new(account: account, provincia: prov, anno: anno).call
      puts "Reconcile #{account.name} #{prov} #{anno}: OK"
    else
      account.reconcile_adozioni_later
      puts "Fan-out ReconcileAccountJob accodato per #{account.name}"
    end
  end
end
