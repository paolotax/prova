# Una riga dell'andamento: un titolo lasciato in una collana, col suo esito.
class Propaganda::Riga
  attr_reader :titolo, :quantita, :esito, :gruppo, :position

  def initialize(titolo:, quantita:, esito:, gruppo:, position:)
    @titolo = titolo
    @quantita = quantita
    @esito = esito
    @gruppo = gruppo
    @position = position
  end

  def da_ritirare?
    esito.nil?
  end

  def rientrata?
    esito == "rientrato"
  end

  def mancante?
    esito == "mancante"
  end
end
