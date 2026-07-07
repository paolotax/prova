class ReconcileAccountJob < ApplicationJob
  queue_as :bulk

  def perform(account)
    account.scuole.where.not(provincia: [nil, ""]).distinct.pluck(:provincia).each do |prov|
      anni.each { |anno| ReconcileAdozioniJob.perform_later(account, provincia: prov, anno: anno) }
    end
  end

  # Riconcilia l'anno corrente e il precedente (storico); [] se l'anagrafe MIUR e' vuota.
  def anni
    corrente = AnnoScolastico.corrente or return []
    [corrente.precedente.to_s, corrente.to_s]
  end
end
