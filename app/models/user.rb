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

  has_secure_password

  validates :name,  presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: /\S+@\S+/ }, uniqueness: { case_sensitive: false }
  validates :partita_iva, format: { with: /\A\d{11}\z/ }
  validates :password, length: { minimum: 6, allow_blank: true }

  has_many :user_scuole, dependent: :destroy  
  has_many :import_scuole, through: :user_scuole

end
