# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  email      :string
#  name       :string
#  navigator  :string
#  role       :integer          default("scagnozzo")
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#  index_users_on_slug   (slug) UNIQUE
#
class User < ApplicationRecord
  include Authenticable
  include User::Avatar
  include User::AvailableFilters

  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name,  presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: /\S+@\S+/ }, uniqueness: { case_sensitive: false }
  #validates :partita_iva, format: { with: /\A\d{11}\z/ }
  #validates :password, length: { minimum: 6, allow_blank: true }

  has_rich_text :card

  has_one :profile
  has_one :personal_info, dependent: :destroy

  # Multi-tenancy
  has_many :memberships, class_name: "Accounts::Membership", dependent: :destroy
  has_many :accounts, through: :memberships

  # Passwordless authentication
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

  has_many :user_scuole, dependent: :destroy
  has_many :import_scuole, through: :user_scuole
  has_many :import_adozioni, through: :import_scuole

  has_many :legacy_mandati, class_name: "LegacyMandato", dependent: :destroy
  has_many :editori, through: :legacy_mandati

  has_many :clienti, dependent: :destroy
  has_many :documenti, dependent: :destroy
  has_many :righe, through: :documenti
  # delirio da riprovare
  #has_many :adozioni, through: :mandati, source: :import_adozione

  has_many :appunti, dependent: :destroy

  has_many :giri, dependent: :destroy
  has_many :propagande, dependent: :destroy

  has_many :tappe, dependent: :destroy

  has_many :libri, dependent: :destroy

  has_many :sconti, dependent: :destroy

  has_many :chats, dependent: :destroy

  has_many :voice_notes, dependent: :destroy

  has_many :import_records, dependent: :destroy

  enum :role, { scagnozzo: 0, sbocciatore: 1, omaccio: 2, admin: 3 }

  # For avatar SVG initials fallback
  def initials
    name.scan(/\b\p{L}/).join.upcase
  end

  after_initialize :set_default_role, :if => :new_record?
  def set_default_role
    self.role ||= :scagnozzo
  end

  delegate :ragione_sociale, :indirizzo, :cap, :citta, :cellulare, :email, :iban, :nome_banca, to: :profile, allow_nil: true, prefix: true

  # Personal info delegates
  delegate :nome, :cognome, :cellulare, :email_personale, :nome_completo, :iniziali,
           to: :personal_info, allow_nil: true, prefix: true

  # Navigator from personal_info (with fallback to user.navigator during migration)
  def effective_navigator
    personal_info&.navigator || navigator
  end

  # Access azienda through primary account (preferred method)
  def account_azienda
    accounts.first&.azienda
  end

  def self.stats
    User.all.collect {|u| { name: u.name, adozioni: Adozione.where(account_id: u.accounts.pluck(:id)).mie.count, appunti: u.appunti.size, giri: u.giri.size, tappe: u.tappe.size } }
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

  # Multi-tenancy helpers
  def member_of?(account)
    accounts.exists?(account.id)
  end

  def role_in(account)
    memberships.find_by(account: account)&.role
  end

  def admin_of?(account)
    role = role_in(account)
    role == "admin" || role == "owner"
  end

  def owner_of?(account)
    role_in(account) == "owner"
  end

  # Can this user modify another user's data?
  def can_change?(other_user)
    self == other_user || admin_of?(Current.account)
  end


  # Passwordless authentication helpers
  def send_magic_link!(purpose: :sign_in, ip_address: nil)
    # Invalidate previous magic links for same purpose
    magic_links.where(purpose: purpose).valid.update_all(expires_at: Time.current)

    magic_link = magic_links.create!(purpose: purpose, ip_address: ip_address)
    MagicLinkMailer.sign_in(self, magic_link).deliver_later
    magic_link
  end

  def revoke_all_sessions!
    sessions.destroy_all
  end

  def revoke_other_sessions!(current_session)
    sessions.where.not(id: current_session.id).destroy_all
  end

  def active?
    true
  end

  def verified?
    true
  end

end
