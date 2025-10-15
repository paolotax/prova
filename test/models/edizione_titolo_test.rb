# == Schema Information
#
# Table name: edizioni_titoli
#
#  id               :bigint           not null, primary key
#  autore           :string
#  codice_isbn      :string
#  titolo_originale :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_edizioni_titoli_on_codice_isbn  (codice_isbn) UNIQUE
#
require "test_helper"

class EdizioneTitoloTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
