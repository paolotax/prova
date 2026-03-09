module PersoneSearchHelper
  class PersonaResult
    attr_reader :persona, :stessa_scuola

    def initialize(persona, stessa_scuola:)
      @persona = persona
      @stessa_scuola = stessa_scuola
    end

    def id
      persona.id
    end

    def to_combobox_display
      persona.nome_completo
    end
  end
end
