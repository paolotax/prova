# app/models/libro/movimenti.rb
class Libro::Movimenti
  attr_reader :libro

  def initialize(libro)
    @libro = libro
  end

  # Righe da documenti attivi, senza consegna, solo padri o senza padre
  def da_consegnare
    righe_base.merge(Documento.attivi)
              .merge(Documento.where.missing(:consegna))
  end

  # Righe da documenti chiusi (con closure), solo padri o senza padre
  def completati
    righe_base.merge(Documento.completati)
  end

  # Righe contate nel riepilogo ma non mostrate nelle altre liste:
  # es. vendite gia consegnate ma non ancora chiuse (hanno consegna, niente closure).
  # Rete di sicurezza: tutto cio che e in righe_base deve comparire da qualche parte.
  def altri
    esclusi = (da_consegnare.to_a + completati.to_a).map(&:id).to_set
    righe_base.to_a.reject { |dr| esclusi.include?(dr.id) }
  end

  # Crosstab: { 2024 => { "ordine" => N, "vendita" => N, "carico" => N, importo: N }, ... }
  def riepilogo_per_anno
    all_righe = righe_base.to_a
    grouped = all_righe.group_by { |dr| dr.documento.data_documento&.year }
    grouped.transform_values { |drs| aggregate(drs) }
           .sort_by { |anno, _| -anno.to_i }
           .to_h
  end

  private

  def righe_base
    DocumentoRiga
      .joins(:riga, documento: :causale)
      .includes(:riga, documento: [:causale, :consegna])
      .where(riga: { libro_id: libro.id })
      .where(documenti: { documento_padre_id: nil })
      .order("documenti.data_documento DESC")
  end

  def aggregate(documento_righe)
    result = Hash.new(0)
    documento_righe.each do |dr|
      causale = dr.documento.causale
      segno = segno_per(causale)
      qta = dr.riga.quantita * segno

      if causale&.carico?
        result[:carichi] += qta
      elsif causale&.vendita?
        if dr.documento.clientable_type == "Cliente"
          result[:vendite_clienti] += qta
        else
          result[:vendite_scuole] += qta
        end
        result[:importo] += dr.riga.importo_cents * segno
      end
    end
    result
  end

  # Vendite: segno invertito (uscita=+, entrata/TD04=-).
  # Resto: segno normale (entrata=+, uscita=-).
  def segno_per(causale)
    return 1 unless causale
    if causale.vendita?
      causale.uscita? ? 1 : -1
    else
      causale.uscita? ? -1 : 1
    end
  end
end
