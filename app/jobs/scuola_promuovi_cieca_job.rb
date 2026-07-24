class ScuolaPromuoviCiecaJob < ApplicationJob
  include BroadcastsControlloRiga

  # :bulk come ScuolaPromuoviClassiJob — gemello cieco del fan-out di massa, tenuto
  # fuori dalla coda :default per non bloccare i job interattivi.
  queue_as :bulk

  def perform(scuola, da:, a:)
    scuola.promuovi_cieca!(da: da, a: a)
    broadcast_riga_controllo(scuola)
  end
end
