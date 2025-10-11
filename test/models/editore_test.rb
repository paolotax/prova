# == Schema Information
#
# Table name: editori
#
#  id         :bigint           not null, primary key
#  editore    :string
#  gruppo     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require "test_helper"

class EditoreTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
