class Libro < ApplicationRecord

  monetize :prezzo_in_cents

  belongs_to :user
  belongs_to :editore, optional: true
  
  has_many :adozioni

  validates :titolo, presence: true
  #validates :codice_isbn, presence: true, uniqueness: true
  #validates :prezzo_in_cents, presence: true, numericality: { greater_than: 0 }

  def self.categorie
    order(:categoria).distinct.pluck(:categoria).compact
  end

  def to_combobox_display
    self.titolo
  end

  # ora così poi devo vedere come funziona money-rails
  def prezzo
    prezzo_in_cents.to_f / 100
  end

  def prezzo=(valore)
    self.prezzo_in_cents = (valore.to_f * 100).to_i
  end

end
