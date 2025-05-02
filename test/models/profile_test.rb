# == Schema Information
#
# Table name: profiles
#
#  id              :integer          not null, primary key
#  user_id         :integer          not null
#  nome            :string
#  cognome         :string
#  ragione_sociale :string
#  indirizzo       :string
#  cap             :string
#  citta           :string
#  cellulare       :string
#  email           :string
#  iban            :string
#  nome_banca      :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_profiles_on_user_id  (user_id)
#

require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
