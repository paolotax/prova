# == Schema Information
#
# Table name: users
#
#  id          :bigint           not null, primary key
#  name        :string
#  email       :string
#  partita_iva :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

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

end
