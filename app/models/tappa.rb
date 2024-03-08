# == Schema Information
#
# Table name: tappe
#
#  id            :bigint           not null, primary key
#  titolo        :string
#  giro          :string
#  ordine        :integer
#  data_tappa    :datetime
#  entro_il      :datetime
#  tappable_type :string           not null
#  tappable_id   :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  giro_id       :bigint
#
class Tappa < ApplicationRecord
  belongs_to :giro
  belongs_to :tappable, polymorphic: true

  scope :di_oggi,   -> { where(data_tappa: Time.now.all_day) }
  scope :di_domani, -> { where(data_tappa: Time.now.tomorrow.all_day) }

  scope :programmate, -> { where("data_tappa > ?", Time.now) }  
  scope :completate,  -> { where.not(data_tappa: nil).where("data_tappa < ?", Time.now) }

  scope :da_programmare, -> { where(data_tappa: nil) }


  def self.search(search)
    if search
      where('titolo LIKE ?', "%#{search}%")
    else
      all
    end
  end


end
