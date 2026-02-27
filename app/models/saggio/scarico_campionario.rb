class Saggio::ScaricoCampionario
  attr_reader :scuola, :saggi, :documento

  def initialize(scuola)
    @scuola = scuola
    @saggi = scuola.saggi.da_scaricare.includes(:libro)
  end

  def genera!
    return nil if saggi.empty?

    causale = Causale.find_by(magazzino: "campionario", tipo_movimento: :vendita, movimento: :uscita)
    raise "Causale campionario non trovata. Creare una causale con magazzino='campionario', tipo_movimento='vendita', movimento='uscita'" unless causale

    ActiveRecord::Base.transaction do
      @documento = Documento.create!(
        user: Current.user,
        causale: causale,
        clientable: scuola,
        data_documento: Date.current,
        numero_documento: next_numero(causale)
      )

      saggi.group_by(&:libro_id).each_with_index do |(libro_id, libro_saggi), idx|
        libro = libro_saggi.first.libro
        quantita_totale = libro_saggi.sum(&:quantita)

        riga = Riga.create!(
          libro: libro,
          quantita: quantita_totale,
          prezzo_cents: 0,
          prezzo_copertina_cents: libro.prezzo_cents || 0
        )

        doc_riga = documento.documento_righe.create!(
          riga: riga,
          posizione: idx + 1
        )

        libro_saggi.each { |s| s.update!(documento_riga: doc_riga) }
      end

      documento.ricalcola_totali!
    end

    documento
  end

  private

  def next_numero(causale)
    ultimo = Documento.where(account: Current.account, causale: causale)
      .where("data_documento >= ?", Date.current.beginning_of_year)
      .maximum(:numero_documento)
    (ultimo || 0) + 1
  end
end
