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
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         authentication_keys: [:login]

  validates :name, presence: true, uniqueness: true
  
  attr_accessor :login

  def login
    @login || self.name || self.email
  end
  
  has_one_attached :avatar
  has_rich_text :card

  #validates :name,  presence: true, uniqueness: { case_sensitive: false }
  #validates :email, format: { with: /\S+@\S+/ }, uniqueness: { case_sensitive: false }
  #validates :partita_iva, format: { with: /\A\d{11}\z/ }
  #validates :password, length: { minimum: 6, allow_blank: true }

  has_many :user_scuole, dependent: :destroy  
  has_many :import_scuole, through: :user_scuole
  has_many :import_adozioni, through: :import_scuole 
  
  has_many :mandati, dependent: :destroy
  
  has_many :editori, through: :mandati

  has_many :adozioni, through: :editori_users

  has_many :appunti, dependent: :destroy

  
  def mie_adozioni
    import_adozioni.where(editore: editori.collect{|e| e.editore})
  end

  def admin?
    self.name == "paolotax"
  end

  def avatar_thumbnail
    if avatar.attached?
      avatar.variant(resize: "150x150!").processed
    else
      "/default_avatar.jpg"
    end
  end


  private

    def after_confirmation
      WelcomeMailer.send_greetings_notification(self)
                  .deliver_now
    end

    def self.find_for_database_authentication(warden_condition)
      conditions = warden_condition.dup
      if(login = conditions.delete(:login))
        where(conditions.to_h).where(["lower(name) = :value OR lower(email) = :value", { value: login.downcase }]).first
      elsif conditions.has_key?(:name) || conditions.has_key?(:email)
        where(conditions.to_h).first
      end
    end

end
