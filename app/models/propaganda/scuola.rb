# L'andamento di una scuola nella propaganda: le collane che le sono state
# lasciate, ciascuna col suo residuo.
class Propaganda::Scuola
  attr_reader :scuola, :collane

  def initialize(scuola:, collane:)
    @scuola = scuola
    @collane = collane
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
end
