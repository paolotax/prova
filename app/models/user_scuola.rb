# == Schema Information
#
# Table name: user_scuole
#
#  id               :bigint           not null, primary key
#  import_scuola_id :bigint           not null
#  user_id          :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class UserScuola < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user
end
