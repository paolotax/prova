class RicalcolaAnomalieJob < ApplicationJob
  # :bulk — ricostruzione completa di controllo_anomalie (tabella globale, non per
  # account): gira a fine import MIUR o su richiesta dallo step Rifinitura.
  queue_as :bulk

  def perform
    ControlloAdozioni::Rebuild.run!
  end
end
