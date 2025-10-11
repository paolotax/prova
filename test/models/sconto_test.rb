# == Schema Information
#
# Table name: sconti
#
#  id                 :bigint           not null, primary key
#  data_fine          :date
#  data_inizio        :date             not null
#  percentuale_sconto :decimal(5, 2)    not null
#  scontabile_type    :string
#  tipo_sconto        :integer          default("vendita"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  categoria_id       :bigint
#  scontabile_id      :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_sconti_on_categoria_id  (categoria_id)
#  index_sconti_on_scontabile    (scontabile_type,scontabile_id)
#  index_sconti_on_user_id       (user_id)
#  index_sconti_unique           (user_id,scontabile_type,scontabile_id,categoria_id,data_inizio,tipo_sconto) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (categoria_id => categorie.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class ScontoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
