# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  name                   :string
#  email                  :string
#  partita_iva            :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  navigator              :string
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#  role                   :integer          default("scagnozzo")
#
class User < ApplicationRecord

  # tutti i metodi di Devise
  include Authenticable
  
  #validates :name,  presence: true, uniqueness: { case_sensitive: false }
  #validates :email, format: { with: /\S+@\S+/ }, uniqueness: { case_sensitive: false }
  #validates :partita_iva, format: { with: /\A\d{11}\z/ }
  #validates :password, length: { minimum: 6, allow_blank: true }

  has_one_attached :avatar
  has_rich_text :card

  has_many :user_scuole, dependent: :destroy  
  
  has_many :import_scuole, through: :user_scuole
  has_many :import_adozioni, through: :import_scuole   
  
  has_many :mie_adozioni, -> { 
      where( EDITORE: Current.user.miei_editori )  
    }, 
    through: :import_scuole, source: :import_adozioni

  has_many :mandati, dependent: :destroy  
  has_many :editori, through: :mandati
  
  # delirio da riprovare 
  #has_many :adozioni, through: :mandati, source: :import_adozione
  
  has_many :appunti, dependent: :destroy

  has_many :giri, dependent: :destroy
  has_many :tappe, dependent: :destroy
  has_many :libri, dependent: :destroy
 
  
  enum role: [ :scagnozzo, :sbocciatore, :omaccio, :admin ]

  after_initialize :set_default_role, :if => :new_record?
  def set_default_role
    self.role ||= :scagnozzo
  end

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
  
end
