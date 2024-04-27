# == Schema Information
#
# Table name: appunti
#
#  id                 :bigint           not null, primary key
#  body               :text
#  email              :string
#  nome               :string
#  stato              :string
#  telefono           :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  import_adozione_id :bigint
#  import_scuola_id   :bigint
#  user_id            :bigint           not null
#
# Indexes
#
#  index_appunti_on_import_adozione_id  (import_adozione_id)
#  index_appunti_on_import_scuola_id    (import_scuola_id)
#  index_appunti_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class AppuntoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
