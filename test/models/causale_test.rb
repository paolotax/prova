# == Schema Information
#
# Table name: causali
#
#  id                 :bigint           not null, primary key
#  causale            :string
#  causali_successive :json
#  clientable_type    :string
#  magazzino          :string
#  movimento          :integer
#  priorita           :integer          default(0)
#  stati_successivi   :json
#  stato_iniziale     :string
#  tipo_movimento     :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_causali_on_priorita        (priorita)
#  index_causali_on_stato_iniziale  (stato_iniziale)
#

require "test_helper"

class CausaleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
