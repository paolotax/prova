# == Schema Information
#
# Table name: documenti
#
#  id                     :bigint           not null, primary key
#  clientable_type        :string
#  consegnato_il          :date
#  data_documento         :date
#  iva_cents              :bigint
#  note                   :text
#  numero_documento       :integer
#  pagato_il              :datetime
#  referente              :text
#  spese_cents            :bigint
#  status                 :integer
#  tipo_documento         :integer
#  tipo_pagamento         :integer
#  totale_cents           :bigint
#  totale_copie           :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  causale_id             :bigint
#  clientable_id          :bigint
#  derivato_da_causale_id :integer
#  documento_padre_id     :integer
#  user_id                :bigint           not null
#
# Indexes
#
#  index_documenti_on_causale_id                         (causale_id)
#  index_documenti_on_clientable_type_and_clientable_id  (clientable_type,clientable_id)
#  index_documenti_on_derivato_da_causale_id             (derivato_da_causale_id)
#  index_documenti_on_documento_padre_id                 (documento_padre_id)
#  index_documenti_on_user_id                            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (derivato_da_causale_id => causali.id)
#  fk_rails_...  (documento_padre_id => documenti.id)
#  fk_rails_...  (user_id => users.id)
#

require "test_helper"

class DocumentoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
