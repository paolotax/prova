# == Schema Information
#
# Table name: giri
#
#  id           :integer          not null, primary key
#  user_id      :integer          not null
#  iniziato_il  :datetime
#  finito_il    :datetime
#  titolo       :string
#  descrizione  :string
#  stato        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  conditions   :text
#  excluded_ids :text
#
# Indexes
#
#  index_giri_on_user_id  (user_id)
#

require "test_helper"

class GiroTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
