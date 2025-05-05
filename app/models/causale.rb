# == Schema Information
#
# Table name: causali
#
#  id              :integer          not null, primary key
#  causale         :string
#  magazzino       :string
#  tipo_movimento  :integer
#  movimento       :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  clientable_type :string
#

class Causale < ApplicationRecord

  enum :tipo_movimento, { ordine: 0, vendita: 1, carico: 2 }

  enum :movimento, { entrata: 0, uscita: 1 }

  validates :causale, presence: true
  validates :tipo_movimento, presence: true
  validates :movimento, presence: true
  validates :magazzino, presence: true

  def to_s
    causale
  end

  def to_combobox_display
    causale # or `title`, `to_s`, etc.
  end

  def descrizione_causale
    if causale == "TD01"
      "Fattura"
    elsif causale == "TD04"
      "Nota di credito"
    elsif causale == "TD24"
      "Fattura"
    else
      causale
    end
  end
end
