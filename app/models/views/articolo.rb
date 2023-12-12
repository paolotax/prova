class Views::Articolo < ApplicationRecord
    
    self.primary_key = "codice_articolo"

    def righe
        Views::Riga.where(codice_articolo: self.codice_articolo).order(:data_documento, :fornitore) 
    end

    scope :trova, -> (query) { where("descrizione ILIKE ? OR codice_articolo ILIKE ?", "%#{query}%",  "%#{query}%") }
    
end


