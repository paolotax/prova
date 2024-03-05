# == Schema Information
#
# Table name: giri
#
#  id          :bigint           not null, primary key
#  user_id     :bigint           not null
#  iniziato_il :datetime
#  finito_il   :datetime
#  titolo      :string
#  descrizione :string
#  stato       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "test_helper"

class GiroTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
