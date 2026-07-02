class ReconcileAdozioniJob < ApplicationJob
  # :bulk come gli altri job di massa (vedi UpdateScuolaMieAdozioniJob):
  # decine di job per account (uno per provincia × anno), fuori dalla coda
  # interattiva. Idempotente: se interrotto si rilancia.
  queue_as :bulk

  def perform(account, provincia:, anno:)
    Current.account = account
    Adozione::Reconciler.new(account: account, provincia: provincia, anno: anno).call
  end
end
