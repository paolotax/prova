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
      return "var(--color-golden)" if documento.golden?
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

end
