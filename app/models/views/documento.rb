class Views::Documento < ApplicationRecord

    
    include PgSearch::Model
    
    pg_search_scope :search_any_word,
                  against: [ :tipo_documento, :numero_documento, :data_documento, :cliente, :fornitore ],
                  using: {
                    tsearch: { any_word: false, prefix: true }
                  }

    self.primary_key = "id"

    def righe
        Views::Riga.where(numero_documento: self.numero_documento,
                          data_documento: self.data_documento,
                          fornitore: self.fornitore).order(:riga)
    end

    scope :trova, -> (query) { where("cliente ILIKE ? OR fornitore ILIKE ? OR numero_documento ILIKE ?", "%#{query}%", "%#{query}%", "%#{query}%") }


end
