class Views::Fornitore < ApplicationRecord

  self.primary_key = "id"

  def righe
    Views::Riga.where(iva_fornitore: self.iva_fornitore).order(numero_documento: :desc)
  end

  scope :trova, -> (query) { where("fornitore ILIKE ? OR iva_fornitore ILIKE ?", "%#{query}%", "%#{query}%") }

end
