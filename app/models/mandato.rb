# == Schema Information
#
# Table name: mandati
#
#  user_id    :integer          not null, primary key
#  editore_id :integer          not null, primary key
#  contratto  :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
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
  
