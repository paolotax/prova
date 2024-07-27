class DocumentoCreator

  def create_documento(documento)
    

    documento.save
    
    if documento.invalid?
      return Result.new(documento: documento, created: false)
    end
    # do some stuff here
    Result.new(documento: documento, created: documento.valid?)
  end

  class Result
    attr_reader :documento
    def initialize(documento:, created:)
      @created = created
      @documento = documento
    end

    def created?
      @created
    end
  end
end