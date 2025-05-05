# == Schema Information
#
# Table name: appunti
#
#  id                 :integer          not null, primary key
#  import_scuola_id   :integer
#  user_id            :integer          not null
#  import_adozione_id :integer
#  nome               :string
#  body               :text
#  email              :string
#  telefono           :string
#  stato              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  completed_at       :datetime
#  team               :string
#  classe_id          :integer
#  voice_note_id      :integer
#  active             :boolean
#
# Indexes
#
#  index_appunti_on_classe_id           (classe_id)
#  index_appunti_on_import_adozione_id  (import_adozione_id)
#  index_appunti_on_import_scuola_id    (import_scuola_id)
#  index_appunti_on_user_id             (user_id)
#  index_appunti_on_voice_note_id       (voice_note_id)
#

require "test_helper"

class AppuntoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
