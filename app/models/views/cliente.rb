class Views::Cliente < ApplicationRecord

  include PgSearch::Model
    
  pg_search_scope :search_any_word,
                against: [ :cliente ],
                using: {
                  tsearch: { any_word: false, prefix: true }
                }



  self.primary_key = "id"

  def righe
    Views::Riga.where(iva_cliente: self.iva_fornitore).order(numero_documento: :desc)
  end

  scope :trova, -> (query) { where("cliente ILIKE ? OR iva_cliente ILIKE ?", "%#{query}%", "%#{query}%") }
end
