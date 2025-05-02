# == Schema Information
#
# Table name: stats
#
#  id              :integer          not null, primary key
#  descrizione     :string
#  seleziona_campi :string
#  raggruppa_per   :string
#  ordina_per      :string
#  condizioni      :string
#  testo           :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

require "test_helper"

class StatTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
