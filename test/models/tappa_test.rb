# == Schema Information
#
# Table name: tappe
#
#  id            :bigint           not null, primary key
#  data_tappa    :datetime
#  descrizione   :string
#  entro_il      :datetime
#  ordine        :integer
#  tappable_type :string           not null
#  titolo        :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  giro_id       :bigint
#  tappable_id   :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  index_tappe_on_giro_id   (giro_id)
#  index_tappe_on_tappable  (tappable_type,tappable_id)
#  index_tappe_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (giro_id => giri.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class TappaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
