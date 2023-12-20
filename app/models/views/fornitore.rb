class Views::Fornitore < ApplicationRecord 

  include PgSearch::Model
    
  pg_search_scope :search_any_word,
                against: [ :fornitore ],
                using: {
                  tsearch: { any_word: false, prefix: true }
                }


  self.primary_key = "id"

  def righe
    Views::Riga.where(iva_fornitore: self.iva_fornitore).order(numero_documento: :desc)
  end

  scope :trova, -> (query) { where("fornitore ILIKE ? OR iva_fornitore ILIKE ?", "%#{query}%", "%#{query}%") }

end
