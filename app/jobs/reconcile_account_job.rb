class ReconcileAccountJob < ApplicationJob
  queue_as :bulk

  ANNI = %w[202526 202627].freeze

  def perform(account)
    account.scuole.where.not(provincia: [nil, ""]).distinct.pluck(:provincia).each do |prov|
      ANNI.each { |anno| ReconcileAdozioniJob.perform_later(account, provincia: prov, anno: anno) }
    end
  end
end
