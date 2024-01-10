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

  has_many :user_scuole
  has_many :import_scuole, through: :user_scuole

end
