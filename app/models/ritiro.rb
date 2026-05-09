class Ritiro
  CAUSALE_TO_ESITO = {
    "Scarico saggi" => :in_saggio,
    "TD01"          => :venduto_fattura,
    "Ordine Scuola" => :venduto_corrispettivi,
    "Mancante"      => :mancante
  }.freeze

  attr_reader :scuola

  def initialize(scuola)
    @scuola = scuola
  end

  def crea_documento(righe:, causale:, clientable:, data:)
    raise ArgumentError, "causale è obbligatoria" if causale.nil?

    Documento.transaction do
      documento = Current.account.documenti.create!(
        causale: causale,
        clientable: clientable,
        data_documento: data,
        numero_documento: prossimo_numero(causale),
        user: Current.user
      )
      righe.each_with_index { |riga, i| processa_riga(riga, documento, i, causale) }
      documento
    end
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

  def prossimo_numero(causale)
    (Current.account.documenti.where(causale: causale).maximum(:numero_documento) || 0) + 1
  end

  def processa_riga(bv_riga, documento, idx, causale)
    riga = Riga.create!(
      libro: bv_riga.libro,
      quantita: bv_riga.quantita,
      prezzo_cents: bv_riga.libro.prezzo_in_cents
    )
    documento.documento_righe.create!(riga: riga, posizione: idx)
    bv_riga.update!(
      esito: CAUSALE_TO_ESITO.fetch(causale.causale),
      processato_at: Time.current
    )
  end

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
