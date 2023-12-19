class Views::Articolo < ApplicationRecord

    include PgSearch::Model
    
    pg_search_scope :search_any_word,
                  against: [ :descrizione, :codice_articolo ],
                  using: {
                    tsearch: { any_word: false, prefix: true }
                  }

    self.primary_key = "codice_articolo"

    def righe
        Views::Riga.where(codice_articolo: self.codice_articolo).order(:data_documento, :fornitore) 
    end

    scope :trova, -> (query) { where("descrizione ILIKE ? OR codice_articolo ILIKE ?", "%#{query}%",  "%#{query}%") }
    
end


