class Libro < ApplicationRecord
  belongs_to :user
  belongs_to :editore


  validates :titolo, presence: true
  #validates :codice_isbn, presence: true, uniqueness: true
  #validates :prezzo_in_cents, presence: true, numericality: { greater_than: 0 }

  def self.categorie
    order(:categoria).distinct.pluck(:categoria).compact
  end

  def prezzo
    prezzo_in_cents.to_f / 100
  end

  def prezzo=(valore)
    self.prezzo_in_cents = (valore.to_f * 100).to_i
  end

end
