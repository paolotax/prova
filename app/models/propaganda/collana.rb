# Il residuo di una collana lasciata a una scuola: le righe (titoli) coi totali
# e il raggruppamento per `gruppo`.
class Propaganda::Collana
  GRUPPO_NULL = "Altro".freeze

  attr_reader :collana, :righe

  def initialize(collana:, righe:)
    @collana = collana
    @righe = righe
  end

  def nome
    collana&.nome.to_s
  end

  def totale
    righe.sum(&:quantita)
  end

  def da_ritirare
    righe.select(&:da_ritirare?).sum(&:quantita)
  end

  def rientrate
    righe.select(&:rientrata?).sum(&:quantita)
  end

  def mancanti
    righe.select(&:mancante?).sum(&:quantita)
  end

  def completata?
    da_ritirare.zero?
  end

  # [[gruppo, [righe]], ...] preservando l'ordine di `position`.
  def gruppi
    righe.group_by { |r| r.gruppo.presence || GRUPPO_NULL }.to_a
  end
end
