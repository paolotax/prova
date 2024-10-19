# == Schema Information
#
# Table name: confezioni
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  confezione_id :bigint
#  fascicolo_id  :bigint
#
require "test_helper"

class ConfezioneTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
