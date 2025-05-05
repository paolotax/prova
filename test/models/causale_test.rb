# == Schema Information
#
# Table name: causali
#
#  id              :integer          not null, primary key
#  causale         :string
#  magazzino       :string
#  tipo_movimento  :integer
#  movimento       :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  clientable_type :string
#

require "test_helper"

class CausaleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
