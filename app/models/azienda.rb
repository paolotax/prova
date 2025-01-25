class Azienda < ApplicationRecord
  belongs_to :user
  
  validates :partita_iva, presence: true, length: { is: 11 }
  validates :codice_fiscale, presence: true, length: { is: 16 }
  validates :denominazione, presence: true
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
    rf01: 'RF01', # Ordinario
    rf02: 'RF02', # Contribuenti minimi
    rf04: 'RF04', # Agricoltura e attività connesse e pesca
    rf05: 'RF05', # Vendita sali e tabacchi
    rf06: 'RF06', # Commercio fiammiferi
    rf07: 'RF07', # Editoria
    rf08: 'RF08', # Gestione servizi telefonia pubblica
    rf09: 'RF09', # Rivendita documenti di trasporto pubblico e di sosta
    rf10: 'RF10', # Intrattenimenti, giochi e altre attività di cui alla tariffa allegata al DPR 640/72
    rf11: 'RF11', # Agenzie viaggi e turismo
    rf12: 'RF12', # Agriturismo
    rf13: 'RF13', # Vendite a domicilio
    rf14: 'RF14', # Rivendita beni usati, oggetti d'arte, d'antiquariato o da collezione
    rf15: 'RF15', # Agenzie di vendite all'asta di oggetti d'arte, antiquariato o da collezione
    rf16: 'RF16', # IVA per cassa P.A.
    rf17: 'RF17', # IVA per cassa
    rf18: 'RF18', # Altro
    rf19: 'RF19'  # Regime forfettario
  }

  def codice_destinatario
    indirizzo_telematico
  end
end 