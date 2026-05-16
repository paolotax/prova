# == Schema Information
#
# Table name: confezione_righe
#
#  id            :bigint           not null, primary key
#  row_order     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  confezione_id :bigint
#  fascicolo_id  :bigint
#

class ConfezioneRiga < ApplicationRecord

  belongs_to :confezione, class_name: "Libro", inverse_of: :confezione_righe
  belongs_to :fascicolo, class_name: "Libro", inverse_of: :fascicolo_righe

  counter_culture :confezione, column_name: "fascicoli_count"
  counter_culture :fascicolo,  column_name: "confezioni_count"

  positioned on: [:confezione_id], column: :row_order

  validates :fascicolo_id, uniqueness: { scope: :confezione_id }
  validate  :no_self_reference

  private

  def no_self_reference
    errors.add(:fascicolo_id, "non puo' coincidere con la confezione") if confezione_id.present? && confezione_id == fascicolo_id
  end
end
