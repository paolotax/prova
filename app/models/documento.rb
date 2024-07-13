# == Schema Information
#
# Table name: documenti
#
#  id               :bigint           not null, primary key
#  consegnato_il    :date
#  data_documento   :date
#  iva_cents        :bigint
#  numero_documento :integer
#  pagato_il        :integer
#  spese_cents      :bigint
#  status           :integer
#  tipo_pagamento   :integer
#  totale_cents     :bigint
#  totale_copie     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  causale_id       :bigint           not null
#  cliente_id       :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_documenti_on_causale_id  (causale_id)
#  index_documenti_on_cliente_id  (cliente_id)
#  index_documenti_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (cliente_id => clienti.id)
#  fk_rails_...  (user_id => users.id)
#
class Documento < ApplicationRecord
  belongs_to :user
  belongs_to :cliente
  belongs_to :causale

  def righe
    []
  end
end
