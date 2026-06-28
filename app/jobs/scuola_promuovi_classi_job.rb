class ScuolaPromuoviClassiJob < ApplicationJob
  queue_as :default

  def perform(scuola, da:, a:, spostamenti_insegnanti: {})
    scuola.promuovi_primaria!(da: da, a: a, spostamenti_insegnanti: spostamenti_insegnanti)
  end
end
