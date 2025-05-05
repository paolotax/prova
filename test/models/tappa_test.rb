# == Schema Information
#
# Table name: tappe
#
#  id            :integer          not null, primary key
#  titolo        :string
#  descrizione   :string
#  data_tappa    :date
#  entro_il      :datetime
#  tappable_type :string           not null
#  tappable_id   :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  giro_id       :integer
#  user_id       :integer
#  position      :integer          not null
#
# Indexes
#
#  index_tappe_on_giro_id                              (giro_id)
#  index_tappe_on_tappable                             (tappable_type,tappable_id)
#  index_tappe_on_user_id                              (user_id)
#  index_tappe_on_user_id_and_data_tappa_and_position  (user_id,data_tappa,position) UNIQUE
#

require "test_helper"

class TappaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
