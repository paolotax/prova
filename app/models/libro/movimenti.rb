# app/models/libro/movimenti.rb
#
# Reader di dettaglio: liste righe + riepilogo per anno.
# I contatori canonici vivono in Giacenza; qui stessa semantica, stesso segno (Causale).
class Libro::Movimenti
  attr_reader :libro, :account

  def initialize(libro, account: Current.account)
    @libro = libro
    @account = account
  end

  # Righe da documenti attivi con residuo da consegnare: complemento esatto di "impegnato"
  # NB: .joins(:riga) aliasa la tabella righe a "riga" (nome dell'associazione)
  def da_consegnare
    righe_base.merge(Documento.attivi).where(<<~SQL)
      riga.quantita > COALESCE((
        SELECT SUM(cr.quantita) FROM consegna_righe cr
        WHERE cr.documento_riga_id = documento_righe.id
      ), 0)
    SQL
  end

  # Righe da documenti chiusi (con closure)
  def completati
    righe_base.merge(Documento.completati)
  end

  # Rete di sicurezza: tutto ciò che è in righe_base deve comparire da qualche parte
  def altri
    esclusi = (da_consegnare.to_a + completati.to_a).map(&:id).to_set
    righe_base.to_a.reject { |dr| esclusi.include?(dr.id) }
  end

  # { 2024 => { carichi:, vendite_clienti:, vendite_scuole:, importo: }, ... }
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
      .includes(:riga, documento: [:causale, :consegne])
      .where(riga: { libro_id: libro.id })
      .where(documenti: { documento_padre_id: nil, account_id: account.id })
      .order("documenti.data_documento DESC")
  end

  def aggregate(documento_righe)
    result = Hash.new(0)
    documento_righe.each do |dr|
      causale = dr.documento.causale
      next unless causale

      if causale.carico?
        result[:carichi] += dr.riga.quantita * causale.segno
      elsif causale.vendita?
        qta = dr.riga.quantita * -causale.segno
        if dr.documento.clientable_type == "Cliente"
          result[:vendite_clienti] += qta
        else
          result[:vendite_scuole] += qta
        end
        result[:importo] += dr.riga.importo_cents * -causale.segno
      end
    end
    result
  end
end
