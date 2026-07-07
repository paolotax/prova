# == Schema Information
#
# Table name: consegna_righe
#
#  id                :uuid             not null, primary key
#  quantita          :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  consegna_id       :uuid             not null
#  documento_riga_id :bigint           not null
#
# Indexes
#
#  index_consegna_righe_on_consegna_id        (consegna_id)
#  index_consegna_righe_on_documento_riga_id  (documento_riga_id)
#
class ConsegnaRiga < ApplicationRecord
  belongs_to :consegna
  belongs_to :documento_riga

  validates :quantita, numericality: { only_integer: true, greater_than: 0 }
end
