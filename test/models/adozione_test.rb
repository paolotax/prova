# == Schema Information
#
# Table name: adozioni
#
#  id                 :bigint           not null, primary key
#  consegnato_il      :datetime
#  importo_cents      :integer
#  note               :text
#  numero_copie       :integer
#  numero_documento   :integer
#  numero_sezioni     :integer
#  pagato_il          :datetime
#  prezzo_cents       :integer
#  stato_adozione     :string
#  status             :integer          default("ordine")
#  team               :string
#  tipo               :integer          default("adozione")
#  tipo_pagamento     :string
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
#  index_adozioni_on_status              (status)
#  index_adozioni_on_tipo                (tipo)
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
