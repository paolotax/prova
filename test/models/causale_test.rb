# == Schema Information
#
# Table name: causali
#
#  id             :bigint           not null, primary key
#  causale        :string
#  magazzino      :string
#  movimento      :integer
#  tipo_movimento :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require "test_helper"

class CausaleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
