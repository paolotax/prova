# == Schema Information
#
# Table name: user_scuole
#
#  id               :integer          not null, primary key
#  import_scuola_id :integer          not null
#  user_id          :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  position         :integer
#
# Indexes
#
#  index_user_scuole_on_import_scuola_id      (import_scuola_id)
#  index_user_scuole_on_user_id               (user_id)
#  index_user_scuole_on_user_id_and_position  (user_id,position)
#

require "test_helper"

class UserScuolaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
