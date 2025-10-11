# == Schema Information
#
# Table name: giri
#
#  id           :bigint           not null, primary key
#  conditions   :text
#  descrizione  :string
#  excluded_ids :text
#  finito_il    :datetime
#  iniziato_il  :datetime
#  stato        :string
#  titolo       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_giri_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

require "test_helper"

class GiroTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
