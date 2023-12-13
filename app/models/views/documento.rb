class Views::Documento < ApplicationRecord
    
    self.primary_key = "id"

    def righe
        Views::Riga.where(numero_documento: self.numero_documento,
                          data_documento: self.data_documento,
                          fornitore: self.fornitore).order(:riga)
    end

    scope :trova, -> (query) { where("cliente ILIKE ? OR fornitore ILIKE ? OR numero_documento ILIKE ?", "%#{query}%", "%#{query}%", "%#{query}%") }


end
