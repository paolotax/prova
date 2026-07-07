class ConsegnaRiga < ApplicationRecord
  belongs_to :consegna
  belongs_to :documento_riga

  validates :quantita, numericality: { only_integer: true, greater_than: 0 }
end
