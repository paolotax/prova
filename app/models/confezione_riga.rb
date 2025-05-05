# == Schema Information
#
# Table name: confezione_righe
#
#  id            :integer          not null, primary key
#  confezione_id :integer
#  fascicolo_id  :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  row_order     :integer
#

class ConfezioneRiga < ApplicationRecord

  belongs_to :confezione, class_name: "Libro"
  belongs_to :fascicolo, class_name: "Libro"

  counter_culture :confezione, column_name: "fascicoli_count"
  counter_culture :fascicolo,  column_name: "confezioni_count"

  positioned on: [:confezione_id], column: :row_order

end
