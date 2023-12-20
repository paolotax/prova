class Views::Articolo < ApplicationRecord

    include PgSearch::Model
    
    pg_search_scope :search_any_word,
                  against: [ :descrizione, :codice_articolo ],
                  using: {
                    tsearch: { any_word: false, prefix: true }
                  }

    self.primary_key = "codice_articolo"

    
    def update_descrizione(descrizione)
      Import.where(codice_articolo: self.codice_articolo).each do |i| 
        i.descrizione = descrizione 
        i.save
      end
    end
    
    def righe
      Views::Riga.where(codice_articolo: self.codice_articolo).order(:data_documento, :fornitore) 
    end

    def self.duplicates
      Views::Articolo.where("codice_articolo IN (SELECT codice_articolo FROM view_articoli GROUP BY codice_articolo HAVING COUNT(*) > 1)")
    end

    def self.codice_non_isbn
      Views::Articolo.where("length(codice_articolo) <> 13")
    end
    
    def self.duplicates_count
      Views::Articolo.where("codice_articolo IN (SELECT codice_articolo FROM view_articoli GROUP BY codice_articolo HAVING COUNT(*) > 1)").count
    end

    def self.duplicate_count_by_codice_articolo
      Views::Articolo.where("codice_articolo IN (SELECT codice_articolo FROM view_articoli GROUP BY codice_articolo HAVING COUNT(*) > 1)").group(:codice_articolo).count
    end

    def self.duplicate_count_by_codice_articolo_and_descrizione
      Views::Articolo.where("codice_articolo IN (SELECT codice_articolo FROM view_articoli GROUP BY codice_articolo HAVING COUNT(*) > 1)").group(:codice_articolo, :descrizione).count
    end

    def self.duplicate_count_by_codice_articolo_and_descrizione_and_fornitore
      Views::Articolo.where("codice_articolo IN (SELECT codice_articolo FROM view_articoli GROUP BY codice_articolo HAVING COUNT(*) > 1)").group(:codice_articolo, :descrizione, :fornitore).count
    end

    def self.duplicate_count_by_codice_articolo_and_descrizione_and_fornitore_and_prezzo
        Views::Articolo.where("codice_articolo IN (SELECT codice_articolo FROM view_articoli GROUP BY codice_articolo HAVING COUNT(*) > 1)").group(:codice_articolo, :descrizione, :fornitore, :prezzo).count
    end

  
    scope :trova, -> (query) { where("descrizione ILIKE ? OR codice_articolo ILIKE ?", "%#{query}%",  "%#{query}%") }
    
end


