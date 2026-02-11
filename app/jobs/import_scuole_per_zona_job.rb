class ImportScuolePerZonaJob < ApplicationJob
  queue_as :default

  def perform(account_zona)
    account = account_zona.account
    account_zona.update!(stato: "importazione")

    count = 0
    account_zona.import_scuole_per_zona.find_each do |import_scuola|
      scuola = Scuola.find_or_create_from_import(import_scuola, account: account)

      Views::Classe.where(codice_ministeriale: import_scuola.CODICESCUOLA).find_each do |view_classe|
        classe = Classe.find_or_create_from_view(view_classe, scuola: scuola, account: account)
        Adozione.import_for_classe(classe)
      end
      count += 1
    end

    account_zona.update!(scuole_count: count, stato: "attiva")
    UpdateMieAdozioniJob.perform_later(account)
  end
end
