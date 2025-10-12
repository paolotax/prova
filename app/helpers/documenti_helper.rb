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
  

end
