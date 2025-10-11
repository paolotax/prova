# == Schema Information
#
# Table name: stats
#
#  id              :bigint           not null, primary key
#  anno            :string
#  categoria       :string
#  condizioni      :string
#  descrizione     :string
#  ordina_per      :string
#  position        :integer
#  raggruppa_per   :string
#  seleziona_campi :string
#  testo           :text
#  titolo          :string
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

require "test_helper"

class StatTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
