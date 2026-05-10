class Ritiro
  CAUSALE_TO_ESITO = {
    "Scarico saggi" => :in_saggio,
    "TD01"          => :venduto_fattura,
    "Ordine Scuola" => :venduto_corrispettivi,
    "Mancante"      => :mancante
  }.freeze

  CAUSALE_TO_SCONTO = {
    "Scarico saggi" => 100.0
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
      documento.mark_consegnato if causale.carico?
      documento
    end
  end

  def bolle_aperte
    @bolle_aperte ||= scuola.bolle_visione
      .where(id: righe_aperte_ids)
      .includes(:collana)
      .ordered
  end
  alias bolle bolle_aperte

  def bolle_chiuse
    @bolle_chiuse ||= scuola.bolle_visione
      .where.not(id: righe_aperte_ids)
      .includes(:collana)
      .ordered
  end

  def righe(bolla)
    righe_per_bolla[bolla]
  end

  def gruppo_per(libro_id, collana_id)
    gruppo_lookup[[collana_id, libro_id]]
  end

  def classi_per(libro_id, collana_id)
    targets = target_lookup[[collana_id, libro_id]].to_s.split(",").map(&:strip)
    classi_per_anno.values_at(*targets).compact.flatten
  end

  def persone_per(libro_id, collana_id)
    classi = classi_per(libro_id, collana_id)
    return Persona.none if classi.empty?
    Persona.docente.joins(:classi).where(classi: { id: classi.map(&:id) }).distinct.order(:cognome)
  end

  def empty?
    bolle_aperte.empty? && bolle_chiuse.empty?
  end

  private

  def prossimo_numero(causale)
    (Current.account.documenti.where(causale: causale).maximum(:numero_documento) || 0) + 1
  end

  def processa_riga(bv_riga, documento, idx, causale)
    riga = Riga.create!(
      libro: bv_riga.libro,
      quantita: bv_riga.quantita,
      prezzo_cents: bv_riga.libro.prezzo_in_cents,
      sconto: CAUSALE_TO_SCONTO.fetch(causale.causale, 0.0)
    )
    documento_riga = documento.documento_righe.create!(riga: riga, posizione: idx)
    bv_riga.update!(
      esito: CAUSALE_TO_ESITO.fetch(causale.causale),
      processato_at: Time.current,
      documento_riga: documento_riga
    )
  end

  def visibili_sql
    "bolla_visione_righe.processato_at IS NULL OR bolla_visione_righe.esito = ?"
  end

  def righe_aperte_ids
    BollaVisioneRiga
      .where(bolla_visione_id: scuola.bolle_visione.select(:id))
      .where(processato_at: nil)
      .select(:bolla_visione_id)
  end

  def righe_per_bolla
    @righe_per_bolla ||= bolle_aperte.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe
        .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
        .includes(:libro)
        .order(:position)
    end
  end

  def gruppo_lookup
    @gruppo_lookup ||= CollanaLibro.where(collana_id: bolle_aperte.map(&:collana_id).uniq)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end

  def target_lookup
    @target_lookup ||= CollanaLibro.where(collana_id: bolle_aperte.map(&:collana_id).uniq)
      .pluck(:collana_id, :libro_id, :classi_target)
      .each_with_object({}) { |(c, l, t), h| h[[c, l]] = t }
  end

  def classi_per_anno
    @classi_per_anno ||= scuola.classi.order(:anno_corso, :sezione).group_by(&:anno_corso)
  end
end
