# == Schema Information
#
# Table name: zone
#
#  id              :bigint           not null, primary key
#  area_geografica :string
#  codice_comune   :string
#  comune          :string
#  provincia       :string
#  regione         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

require "test_helper"

class ZonaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
