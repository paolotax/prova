class Views::Cliente < ApplicationRecord

  self.primary_key = "id"

  def righe
    Views::Riga.where(iva_cliente: self.iva_fornitore).order(numero_documento: :desc)
  end

  scope :trova, -> (query) { where("cliente ILIKE ? OR iva_cliente ILIKE ?", "%#{query}%", "%#{query}%") }
end
