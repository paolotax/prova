# == Schema Information
#
# Table name: giri
#
#  id          :bigint           not null, primary key
#  user_id     :bigint           not null
#  iniziato_il :datetime
#  finito_il   :datetime
#  titolo      :string
#  descrizione :string
#  stato       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Giro < ApplicationRecord
  belongs_to :user
  has_many :tappe, dependent: :destroy

  accepts_nested_attributes_for :tappe

  validates :titolo, presence: true
  
  def tappe_count
    tappe.count
  end

  def tappe_incomplete_count
    tappe.where(data_tappa: nil).count
  end

  def tappe_programmate_count
    tappe.where("data_tappa > ?", Time.now).count
  end

  def tappe_completate_count
    tappe.where("data_tappa < ?", Time.now).count
  end

end
