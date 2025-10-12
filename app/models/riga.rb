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

  before_validation :set_default_value
  after_save :aggiorna_totali_documenti
  after_destroy :aggiorna_totali_documenti

  def prezzo
    prezzo_cents / 100.0
  end

  def prezzo=(prezzo)
    self.prezzo_cents = (BigDecimal(prezzo) * 100).to_i
  end

  def prezzo_scontato
    (prezzo_cents - (prezzo_cents * (sconto || 0.0)) / 100.0)
  end

  def importo
    (prezzo_scontato * quantita) / 100.0
  end

  def importo_cents
    sconto_cents = ((prezzo_cents * (sconto || 0.0)) / 100.0)
    (prezzo_cents - sconto_cents) * quantita
  end

  def ordine
    documenti.where("status = 0").first || ' nessuno '
  end

  private

    def set_default_value
      self.sconto ||= 0.0
    end

    def aggiorna_totali_documenti
      # Aggiorna i totali di tutti i documenti che contengono questa riga
      documenti.each(&:ricalcola_totali!)
    end

end
