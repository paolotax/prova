class Ritiro
  attr_reader :scuola

  def initialize(scuola)
    @scuola = scuola
  end

  def bolle
    @bolle ||= scuola.bolle_visione
      .joins(:bolla_visione_righe)
      .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
      .includes(:collana)
      .distinct.ordered
  end

  def righe(bolla)
    righe_per_bolla[bolla]
  end

  def gruppo_per(libro_id, collana_id)
    gruppo_lookup[[collana_id, libro_id]]
  end

  def empty?
    bolle.empty?
  end

  private

  def visibili_sql
    "bolla_visione_righe.processato_at IS NULL OR bolla_visione_righe.esito = ?"
  end

  def righe_per_bolla
    @righe_per_bolla ||= bolle.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe
        .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
        .includes(:libro)
        .order(:position)
    end
  end

  def gruppo_lookup
    @gruppo_lookup ||= CollanaLibro.where(collana_id: bolle.map(&:collana_id).uniq)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end
end
