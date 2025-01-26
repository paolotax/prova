# == Schema Information
#
# Table name: aziende
#
#  id                   :bigint           not null, primary key
#  banca                :string
#  cap                  :string(5)        not null
#  codice_fiscale       :string(16)       not null
#  comune               :string           not null
#  email                :string           not null
#  iban                 :string(27)
#  indirizzo            :string           not null
#  indirizzo_telematico :string(7)
#  nazione              :string(2)        default("IT"), not null
#  partita_iva          :string(11)       not null
#  provincia            :string(2)        not null
#  ragione_sociale      :string           not null
#  regime_fiscale       :string           default(NULL), not null
#  telefono             :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_aziende_on_codice_fiscale  (codice_fiscale) UNIQUE
#  index_aziende_on_partita_iva     (partita_iva) UNIQUE
#  index_aziende_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Azienda < ApplicationRecord
  belongs_to :user
  
  validates :partita_iva, presence: true, length: { is: 11 }
  validates :codice_fiscale, presence: true, length: { is: 16 }
  validates :ragione_sociale, presence: true
  validates :regime_fiscale, presence: true
  validates :indirizzo, presence: true
  validates :cap, presence: true, length: { is: 5 }
  validates :comune, presence: true
  validates :provincia, presence: true, length: { is: 2 }
  validates :nazione, presence: true, length: { is: 2 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :telefono, presence: true
  validates :indirizzo_telematico, presence: true, length: { is: 7 }
  
  # Dati bancari
  validates :iban, presence: true, length: { is: 27 }
  validates :banca, presence: true

  # Enum per il regime fiscale secondo specifiche SDI
  enum :regime_fiscale, {
    rf01: 'RF01 - Ordinario', # Ordinario
    rf02: 'RF02 - Contribuenti minimi', # Contribuenti minimi
    rf04: 'RF04 - Agricoltura e attività connesse e pesca', # Agricoltura e attività connesse e pesca
    rf05: 'RF05 - Vendita sali e tabacchi', # Vendita sali e tabacchi
    rf06: 'RF06 - Commercio fiammiferi', # Commercio fiammiferi
    rf07: 'RF07 - Editoria', # Editoria
    rf08: 'RF08 - Gestione servizi telefonia pubblica', # Gestione servizi telefonia pubblica
    rf09: 'RF09 - Rivendita documenti di trasporto pubblico e di sosta', # Rivendita documenti di trasporto pubblico e di sosta
    rf10: 'RF10 - Intrattenimenti, giochi e altre attività di cui alla tariffa allegata al DPR 640/72', # Intrattenimenti, giochi e altre attività di cui alla tariffa allegata al DPR 640/72
    rf11: 'RF11 - Agenzie viaggi e turismo', # Agenzie viaggi e turismo
    rf12: 'RF12 - Agriturismo', # Agriturismo
    rf13: 'RF13 - Vendite a domicilio', # Vendite a domicilio
    rf14: 'RF14 - Rivendita beni usati, oggetti d\'arte, d\'antiquariato o da collezione', # Rivendita beni usati, oggetti d'arte, d'antiquariato o da collezione
    rf15: 'RF15 - Agenzie di vendite all\'asta di oggetti d\'arte, antiquariato o da collezione', # Agenzie di vendite all'asta di oggetti d'arte, antiquariato o da collezione
    rf16: 'RF16 - IVA per cassa P.A.', # IVA per cassa P.A.
    rf17: 'RF17 - IVA per cassa', # IVA per cassa
    rf18: 'RF18 - Altro', # Altro
    rf19: 'RF19 - Regime forfettario' # Regime forfettario
  }

  def codice_destinatario
    indirizzo_telematico
  end
end 
