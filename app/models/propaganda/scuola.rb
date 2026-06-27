# L'andamento di una scuola nella propaganda: le collane che le sono state
# lasciate, ciascuna col suo residuo.
class Propaganda::Scuola
  attr_reader :scuola, :collane

  def initialize(scuola:, collane:)
    @scuola = scuola
    @collane = collane
  end

  def totale
    collane.sum(&:totale)
  end

  def da_ritirare
    collane.sum(&:da_ritirare)
  end

  def mancanti
    collane.sum(&:mancanti)
  end

  def completata?
    collane.all?(&:completata?)
  end

  # Ritiro mai avviato: tutti i libri sono ancora da ritirare.
  def da_avviare?
    da_ritirare.positive? && da_ritirare == totale
  end

  # Ritiro avviato ma non finito: alcuni libri ritirati/segnati, altri no.
  def parziale?
    da_ritirare.positive? && da_ritirare < totale
  end
end
