class ScuolaPromuoviClassiJob < ApplicationJob
  include BroadcastsControlloRiga

  # :bulk — è il figlio del fan-out delle promozioni di massa (migliaia). Tenuto fuori
  # dalla coda :default per non bloccare i job interattivi (broadcast, azioni utente).
  queue_as :bulk

  def perform(scuola, da:, a:, spostamenti_insegnanti: {})
    scuola.promuovi_primaria!(da: da, a: a, spostamenti_insegnanti: spostamenti_insegnanti)
    broadcast_riga_controllo(scuola)
  end
end
