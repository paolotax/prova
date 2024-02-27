# == Schema Information
#
# Table name: mandati
#
#  user_id    :bigint           not null, primary key
#  editore_id :bigint           not null, primary key
#  contratto  :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Mandato < ApplicationRecord
    belongs_to :editore
    belongs_to :user
end
  
