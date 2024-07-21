class DocumentoCreator
  
  #include ActiveModel::Model

  #attr_accessor :documento

  def initialize(documento:)
    @documento = documento
  end

  def mostra_importo
    @documento.righe.sum(&:importo)
  end

  def mostra_copie
    @documento.righe.sum(&:quantita)
  end
end
