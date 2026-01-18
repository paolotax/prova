module DocumentiHelper

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

end
