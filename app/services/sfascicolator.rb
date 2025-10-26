class Sfascicolator

  def initialize(libro:, documento:, quantita: 1, sconto: 0.0)
    @libro = libro
    @documento = documento
    @quantita = quantita
    @sconto = sconto
  end

  def generate!
    @libro.fascicoli.each do |fascicolo|
      documento_riga = DocumentoRiga.build(documento: @documento)
      documento_riga.build_riga(
        libro_id: fascicolo.id,
        prezzo_cents: fascicolo.prezzo_in_cents,
        sconto: @sconto,
        quantita: @quantita
      )
      documento_riga.save!
    end
  end

end