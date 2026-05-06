module Ritiro
  class CreaDocumento
    CAUSALE_TO_ESITO = {
      "Scarico saggi" => :in_saggio,
      "TD01"          => :venduto_fattura,
      "Ordine Scuola" => :venduto_corrispettivi,
      "Mancante"      => :mancante
    }.freeze

    def initialize(righe:, causale:, clientable:, data:)
      @righe = righe
      @causale = causale
      @clientable = clientable
      @data = data
    end

    def call
      raise ArgumentError, "causale è obbligatoria" if @causale.nil?

      # Single transaction: if any record creation fails, all writes (Documento, Riga,
      # DocumentoRiga, BV update) rollback.
      Documento.transaction do
        documento = build_documento
        documento.save!
        @righe.each_with_index { |bv_riga, idx| processa_riga(bv_riga, documento, idx) }
        documento
      end
    end

    private

    def build_documento
      Current.account.documenti.new(
        causale: @causale,
        clientable: @clientable,
        data_documento: @data,
        numero_documento: prossimo_numero,
        user: Current.user
      )
    end

    # TODO race: MAX+1 has a TOCTOU race under concurrent calls. Acceptable for now (single-user mobile flow);
    # add a unique index on (account_id, causale_id, numero_documento) + retry-on-conflict before scaling.
    def prossimo_numero
      max = Current.account.documenti.where(causale: @causale).maximum(:numero_documento) || 0
      max + 1
    end

    def processa_riga(bv_riga, documento, idx)
      riga = Riga.create!(
        libro: bv_riga.libro,
        quantita: bv_riga.quantita,
        prezzo_cents: bv_riga.libro.prezzo_in_cents
      )
      doc_riga = documento.documento_righe.create!(riga: riga, posizione: idx)
      bv_riga.update!(
        esito: CAUSALE_TO_ESITO.fetch(@causale.causale),
        documento_riga: doc_riga,
        processato_at: Time.current
      )
    end
  end
end
