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

  #scope :per_comune_e_direzione, -> { joins(:tappable).order('scuole.comune, scuole.direzione') }

  scope :search, ->(search) { 
        joins("INNER JOIN import_scuole ON tappe.tappable_id = import_scuole.id AND tappe.tappable_type = 'ImportScuola'")
        .where('import_scuole."DENOMINAZIONESCUOLA" ILIKE ? OR import_scuole."DESCRIZIONECOMUNE" ILIKE ? OR import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO" ILIKE ? OR tappe."titolo" ILIKE ?', 
        "%#{search}%", "%#{search}%","%#{search}%", "%#{search}%") 
  }

  scope :del_giorno, ->(data) { where(data_tappa: data.to_date.all_day) }
  

end
