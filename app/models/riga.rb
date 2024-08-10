# == Schema Information
#
# Table name: righe
#
#  id                     :bigint           not null, primary key
#  iva_cents              :integer          default(0)
#  prezzo_cents           :integer          default(0)
#  prezzo_copertina_cents :integer          default(0)
#  quantita               :integer          default(1)
#  sconto                 :decimal(5, 2)    default(0.0)
#  status                 :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  libro_id               :bigint           not null
#
# Indexes
#
#  index_righe_on_libro_id  (libro_id)
#
# Foreign Keys
#
#  fk_rails_...  (libro_id => libri.id)
#
class Riga < ApplicationRecord
  belongs_to :libro

  has_many :documento_righe
  has_many :documenti, through: :documento_righe


  attr_accessor :prezzo, :importo, :importo_cents 

  def prezzo
    prezzo_cents / 100.0
  end

  def prezzo=(prezzo)
    self.prezzo_in_cents = (BigDecimal(prezzo) * 100).to_i
  end

  def prezzo_scontato
    sc = sconto || 0.0
    (prezzo - (prezzo * sc) / 100.0).round(2)
  end

  def importo
    prezzo_scontato * quantita
  end

  def importo_cents
    sconto_cents = ((prezzo_cents * sconto) / 100.0)
    (prezzo_cents - sconto_cents) * quantita
  end
  
  def self.aggiorna_prezzi
    Riga.all.each do |r|
      r.update(prezzo_cents: r.libro.prezzo_in_cents)
    end
  end       
  
end
