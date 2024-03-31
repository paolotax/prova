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
  scope :del_giorno, ->(data) { where(data_tappa: data.to_date.all_day) }
  
  scope :delle_scuole_di, ->(scuole_ids) { where(tappable_id: scuole_ids)}

  scope :attuali, -> { where("data_tappa > ? OR data_tappa IS NULL", Time.now.beginning_of_day) }

  scope :programmate, -> { where("data_tappa > ?", Time.now) }  
  
  scope :completate,  -> { where("data_tappa < ?", Time.now.beginning_of_day) }

  scope :da_programmare, -> { where(data_tappa: nil) }

  scope :per_ordine_e_data, -> { order(:ordine, :data_tappa) }
  scope :per_ordine_e_data_desc, -> { order(:ordine, data_tappa: :desc) }
  
  scope :per_data, -> { order(:data_tappa, :ordine) }
  scope :per_data_desc, -> { order([data_tappa: :desc], :ordine) }
  
  scope :per_ordine, -> { order(:ordine) }
  
  scope :per_titolo, -> { order(:titolo) }
  scope :per_comune_e_direzione, -> { joins(:tappable).order('import_scuole."DESCRIZIONECOMUNE", import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO"') }

  #scope :per_comune_e_direzione, -> { joins(:tappable).order('scuole.comune, scuole.direzione') }

  scope :search, ->(search) { 
        joins("INNER JOIN import_scuole ON tappe.tappable_id = import_scuole.id AND tappe.tappable_type = 'ImportScuola'")
        .where('import_scuole."DENOMINAZIONESCUOLA" ILIKE ? OR import_scuole."DESCRIZIONECOMUNE" ILIKE ? OR import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO" ILIKE ? OR tappe."titolo" ILIKE ?', 
        "%#{search}%", "%#{search}%","%#{search}%", "%#{search}%") 
  }

  def attuale?
    data_tappa.nil? || data_tappa > Time.now.beginning_of_day 
  end


end
