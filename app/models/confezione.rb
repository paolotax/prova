# == Schema Information
#
# Table name: confezioni
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  confezione_id :bigint
#  fascicolo_id  :bigint
#
class Confezione < ApplicationRecord
  belongs_to :confezione, class_name: "Libro"
  belongs_to :fascicolo, class_name: "Libro"
end
