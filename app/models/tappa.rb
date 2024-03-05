# == Schema Information
#
# Table name: tappe
#
#  id            :bigint           not null, primary key
#  titolo        :string
#  giro          :string
#  ordine        :integer
#  data_tappa    :datetime
#  entro_il      :datetime
#  tappable_type :string           not null
#  tappable_id   :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  giro_id       :bigint
#
class Tappa < ApplicationRecord
  belongs_to :giro
  belongs_to :tappable, polymorphic: true
end
