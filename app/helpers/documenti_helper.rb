module DocumentiHelper

    # Returns golden-effect class if documento is golden
    def documento_golden_class(documento)
      documento.golden? ? "golden-effect" : ""
    end

    # Colori per i documenti basati sulla causale
    def documento_header_bg_classes(documento)
      #return "bg-red-200" if documento.incompleto?
      #return "bg-green-200" if documento.pagato?

      causale_bg_class(documento.causale)
    end

    def documento_footer_bg_classes(documento)
      documento_header_bg_classes(documento)
    end

    # Returns BEM modifier class based on documento's causale
    # e.g., "documento--ordine-entrata", "documento--vendita-uscita"
    def documento_causale_modifier(documento)
      return "" unless documento&.causale

      tipo = documento.causale.tipo_movimento
      mov = documento.causale.movimento

      "documento--#{tipo}-#{mov}"
    end

    # Returns CSS color for card based on documento's causale
    # Colors aligned with causale_bg_class but as oklch values
    def documento_color(documento)
      return "oklch(0.6 0.01 0)" if documento.closed?
      return "oklch(0.6 0.01 0)" if documento.postponed?
      return "oklch(0.7 0.01 0)" unless documento&.causale  # gray
      causale_color(documento.causale)
    end

    # Returns CSS color based on causale's tipo_movimento and movimento
    def causale_color(causale)
      return "oklch(0.7 0.01 0)" unless causale

      tipo = causale.tipo_movimento
      mov = causale.movimento

      case [tipo, mov]
      when ["ordine", "entrata"]   then "oklch(0.6 0.15 250)"  # blue
      when ["ordine", "uscita"]    then "oklch(0.55 0.15 280)" # indigo
      when ["vendita", "entrata"]  then "oklch(0.6 0.15 160)"  # emerald
      when ["vendita", "uscita"]   then "oklch(0.6 0.15 15)"   # rose
      when ["carico", "entrata"]   then "oklch(0.7 0.15 85)"   # amber
      when ["carico", "uscita"]    then "oklch(0.65 0.15 50)"  # orange
      else "oklch(0.7 0.01 0)"                                 # gray
      end
    end

    def tipi_pagamento_options
      Pagamento::TIPI_PAGAMENTO.map { |value, label| [label, value] }
    end

    # Variante con cui rendere un documento nella lista index: :row in vista
    # tabella (default), :card in vista card. Letta dal cookie impostato dal
    # DocumentiController. Usata dai turbo_stream dei bulk per non rerenderizzare
    # una card dentro la tabella.
    def documento_list_variant
      cookies[:documenti_vista] == "card" ? :card : :row
    end

    # Rende un singolo elemento-lista del documento nella variante corrente.
    def render_documento_list_item(documento, entry: nil)
      if documento_list_variant == :row
        render "documenti/table/row", documento: documento, entry: entry
      else
        render "documenti/documento", documento: documento, entry: entry
      end
    end

    # Badge di stato per la index a tabella: mostra la colonna triage,
    # "Da gestire", "Rimandato" o "Completato".
    def documento_stato_badge(documento)
      stato_badge_for(documento)
    end

    # JSON per lo Stimulus controller documento-editor
    def documento_editor_json(documento)
      {
        id: documento.id,
        causale_id: documento.causale_id,
        clientable_id: documento.clientable_id,
        clientable_type: documento.clientable_type,
        numero_documento: documento.numero_documento,
        data_documento: documento.data_documento,
        referente: documento.referente,
        note: documento.note
      }.to_json
    end

    def documento_editor_righe_json(documento)
      documento.documento_righe.includes(riga: :libro).map { |doc_riga|
        riga = doc_riga.riga
        {
          documento_riga_id: doc_riga.id,
          riga_id: riga.id,
          libro_id: riga.libro_id,
          libro: {
            id: riga.libro&.id,
            titolo: riga.libro&.titolo,
            codice_isbn: riga.libro&.codice_isbn
          },
          titolo: riga.libro&.titolo,
          codice_isbn: riga.libro&.codice_isbn,
          quantita: riga.quantita,
          prezzo_cents: riga.prezzo_cents,
          sconto: riga.sconto
        }
      }.to_json
    end

end
