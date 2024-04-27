# == Schema Information
#
# Table name: adozioni
#
#  id                 :bigint           not null, primary key
#  importo_cents      :integer
#  note               :text
#  numero_copie       :integer
#  numero_sezioni     :integer
#  prezzo_cents       :integer
#  stato_adozione     :string
#  team               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  classe_id          :bigint
#  import_adozione_id :bigint
#  libro_id           :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_adozioni_on_classe_id           (classe_id)
#  index_adozioni_on_import_adozione_id  (import_adozione_id)
#  index_adozioni_on_libro_id            (libro_id)
#  index_adozioni_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (libro_id => libri.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class AdozioneTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
