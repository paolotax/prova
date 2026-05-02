class RebuildAccountAdozioniJob < ApplicationJob
  queue_as :default

  # Orchestratore "rifai i conti" account-wide.
  # Backfill direzioni residue + ricalcolo mie adozioni in un solo worker,
  # in serie e nello stesso processo. Usato dal bottone "aggiorna mie
  # adozioni" e dal rake `zone:rebuild`.
  def perform(account)
    BackfillDirezioniJob.perform_now(account)
    UpdateMieAdozioniJob.perform_now(account)
  end
end
