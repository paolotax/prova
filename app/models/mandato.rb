# == Schema Information
#
# Table name: mandati
#
#  contratto  :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  editore_id :bigint           not null, primary key
#  user_id    :bigint           not null, primary key
#
# Indexes
#
#  index_mandati_on_editore_id  (editore_id)
#  index_mandati_on_user_id     (user_id)
#

class Mandato < ApplicationRecord
    belongs_to :editore
    belongs_to :user
end
  
