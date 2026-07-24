class ScuolaPromuoviCiecaJob < ApplicationJob
  # :bulk come ScuolaPromuoviClassiJob — gemello cieco del fan-out di massa, tenuto
  # fuori dalla coda :default per non bloccare i job interattivi.
  queue_as :bulk

  def perform(scuola, da:, a:)
    scuola.promuovi_cieca!(da: da, a: a)
  end
end
