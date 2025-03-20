# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  navigator              :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("scagnozzo")
#  slug                   :string
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_slug                  (slug) UNIQUE
#
class User < ApplicationRecord

  # tutti i metodi di Devise
  include Authenticable
  
  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name,  presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: /\S+@\S+/ }, uniqueness: { case_sensitive: false }
  #validates :partita_iva, format: { with: /\A\d{11}\z/ }
  #validates :password, length: { minimum: 6, allow_blank: true }

  has_one_attached :avatar
  has_rich_text :card

  has_one :profile
  
  has_many :user_scuole, dependent: :destroy    
  has_many :import_scuole, through: :user_scuole
  has_many :import_adozioni, through: :import_scuole   

  has_many :classi, through: :import_scuole  
  
  has_many :mie_adozioni, -> { 
      where( EDITORE: Current.user.miei_editori )  
    }, 
    through: :import_scuole, source: :import_adozioni

  has_many :mandati, dependent: :destroy  
  has_many :editori, through: :mandati

  has_many :adozioni, dependent: :destroy

  has_many :clienti, dependent: :destroy
  has_many :documenti, dependent: :destroy
  has_many :righe, through: :documenti
  # delirio da riprovare 
  #has_many :adozioni, through: :mandati, source: :import_adozione
  
  has_many :appunti, dependent: :destroy

  has_many :giri, dependent: :destroy
  
  has_many :tappe, dependent: :destroy
  
  has_many :libri, dependent: :destroy

  has_many :chats, dependent: :destroy

  has_many :voice_notes, dependent: :destroy
 
  
  enum :role, [ :scagnozzo, :sbocciatore, :omaccio, :admin ]

  after_initialize :set_default_role, :if => :new_record?
  def set_default_role
    self.role ||= :scagnozzo
  end

  delegate :ragione_sociale, :indirizzo, :cap, :citta, :cellulare, :email, :iban, :nome_banca, to: :profile, allow_nil: true, prefix: true
  

  has_one :azienda

  delegate :partita_iva, :codice_fiscale, :ragione_sociale, :regime_fiscale,
          :indirizzo, :cap, :comune, :provincia, :nazione,
          :email, :telefono, :indirizzo_telematico,
          :iban, :banca,
          to: :azienda, allow_nil: true, prefix: true
  
  def miei_editori
    editori.collect{|e| e.editore}
  end
  
  def avatar_thumbnail
    if avatar.attached?
      avatar.variant(resize: "150x150!").processed
    else
      "/default_avatar.jpg"
    end
  end

  def zone
    import_scuole.joins(:tipo_scuola).group(:REGIONE, :PROVINCIA, :grado).count
  end

  def self.stats
    User.all.collect {|u| { name: u.name, adozioni: u.mie_adozioni.size, appunti: u.appunti.size, giri: u.giri.size, tappe: u.tappe.size } }
  end

  def self.create_aziende_from_profiles
    User.all.each do |user|
      user.create_azienda
      user.azienda.ragione_sociale = user&.profile&.ragione_sociale
      user.azienda.indirizzo = user&.profile&.indirizzo
      user.azienda.cap = user&.profile&.cap
      user.azienda.comune = user&.profile&.citta
      user.azienda.email = user&.profile&.email
      user.azienda.telefono = user&.profile&.cellulare
      user.azienda.iban = user&.profile&.iban
      user.azienda.banca = user&.profile&.nome_banca
      user.azienda.save!
    end
  end

  def qrcodes
    Qrcode.where(qrcodable_type: "Libro", qrcodable_id: libri.pluck(:id))
          .or(Qrcode.where(qrcodable_type: "Scuola", qrcodable_id: import_scuole.pluck(:id)))
  end

end
