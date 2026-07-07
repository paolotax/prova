# Value object per l'anno scolastico MIUR nel formato "AAAABB" (es. "202526").
# Centralizza Miur.anno_corrente, lo scorrimento e la label umana, togliendo
# gli anni hardcoded sparsi nei job/controller.
class AnnoScolastico
  include Comparable

  def self.corrente
    v = Miur.anno_corrente
    v && new(v)
  end

  def initialize(valore)
    @valore = valore.to_s
  end

  attr_reader :valore
  alias to_s valore

  def successivo = self.class.new(scorri(+1))
  def precedente = self.class.new(scorri(-1))

  def label = "#{valore[0, 4]}/#{valore[4, 2]}"

  def <=>(other) = valore <=> other.to_s
  def eql?(other) = other.is_a?(self.class) && valore == other.valore
  def hash = valore.hash

  private

  # "202526" -> inizio 2025; scorri(+1) -> "202627".
  def scorri(delta)
    inizio = valore[0, 4].to_i + delta
    format("%<a>d%<b>02d", a: inizio, b: (inizio + 1) % 100)
  end
end
