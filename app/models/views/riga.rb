class Views::Riga < ApplicationRecord

    def documento 
        
        Views::Documento.where(
            numero_documento: self.numero_documento, 
            data_documento: self.data_documento, 
            fornitore: self.fornitore 
        ).first
      
    end

end
