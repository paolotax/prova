# == Schema Information
#
# Table name: confezioni
#
#  id            :bigint           not null, primary key
#  row_order     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  confezione_id :bigint
#  fascicolo_id  :bigint
#
class ConfezioneRiga < ApplicationRecord
  belongs_to :confezione, class_name: "Libro"
  belongs_to :fascicolo, class_name: "Libro"

  counter_culture :confezione, column_name: "fascicoli_count"
  
  # include RankedModel
  # ranks :row_order, with_same: :confezione_id

  #acts_as_list scope: [:confezione_id], column: "row_order"

  positioned on: :confezione, column: :row_order
end
