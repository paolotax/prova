# == Schema Information
#
# Table name: appunti
#
#  id                 :bigint           not null, primary key
#  import_scuola_id   :bigint           not null
#  user_id            :bigint           not null
#  import_adozione_id :bigint
#  nome               :string
#  body               :text
#  email              :string
#  telefono           :string
#  stato              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require "test_helper"

class AppuntoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
