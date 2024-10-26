class Sfascicolator
  
  def initialize(libro:, documento:, quantita: 0)
    @libro = libro
    @documento = documento
    @quantita = quantita
  end

  def generate!
    @libro.fascicoli.each do |fascicolo|
      documento_riga = DocumentoRiga.build(documento: @documento)
      documento_riga.build_riga(libro_id: fascicolo.id, prezzo: fascicolo.prezzo.to_f, sconto: 0.0, quantita: @quantita)
      documento_riga.save!
    end
  end

end