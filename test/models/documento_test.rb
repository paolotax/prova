# == Schema Information
#
# Table name: documenti
#
#  id               :integer          not null, primary key
#  numero_documento :integer
#  user_id          :integer          not null
#  data_documento   :date
#  causale_id       :integer
#  tipo_pagamento   :integer
#  consegnato_il    :date
#  status           :integer
#  iva_cents        :integer
#  totale_cents     :integer
#  spese_cents      :integer
#  totale_copie     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  clientable_id    :integer
#  clientable_type  :string
#  tipo_documento   :integer
#  note             :text
#  referente        :text
#  pagato_il        :datetime
#
# Indexes
#
#  index_documenti_on_causale_id                         (causale_id)
#  index_documenti_on_clientable_type_and_clientable_id  (clientable_type,clientable_id)
#  index_documenti_on_user_id                            (user_id)
#

require "test_helper"

class DocumentoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
