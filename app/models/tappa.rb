# == Schema Information
#
# Table name: tappe
#
#  id            :bigint           not null, primary key
#  data_tappa    :date
#  descrizione   :string
#  entro_il      :datetime
#  position      :integer          not null
#  tappable_type :string           not null
#  titolo        :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  giro_id       :bigint
#  tappable_id   :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  index_tappe_on_giro_id                              (giro_id)
#  index_tappe_on_tappable                             (tappable_type,tappable_id)
#  index_tappe_on_user_id                              (user_id)
#  index_tappe_on_user_id_and_data_tappa_and_position  (user_id,data_tappa,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (giro_id => giri.id)
#  fk_rails_...  (user_id => users.id)
#
class Tappa < ApplicationRecord

  belongs_to :user
  
  belongs_to :giro, optional: true, touch: true
  belongs_to :tappable, polymorphic: true

  positioned on: [:user, :data_tappa], column: :position

  
  # controllare se filtrare per user_id
  # NON FUNZIONA TAPPA
  # belongs_to :import_scuola, -> { where(tappable_type == 'ImportScuola') }, class_name: 'ImportScuola', foreign_key: 'tappable_id'
  # def import_scuola
  #   return unless tappable_type == 'ImportScuola'
  #   super
  # end

  # # belongs_to :cliente, class_name: 'Cliente', foreign_key: 'tappable_id'
  # # def cliente
  # #   return nil unless tappable_type == 'Cliente'
  # #   super
  # # end
  
  scope :ultima, -> { order(created_at: :desc).first }
  
  scope :ultima_tappa_passata, -> { order(data_tappa: :desc).where("data_tappa < ?", Date.today).first }
  scope :tappe_future, -> { order(data_tappa: :asc).where("data_tappa >= ?", Date.today) }

  scope :con_data_tappa, -> { where.not(data_tappa: nil) }
  
  scope :di_oggi,   -> { where(data_tappa: Date.today) }
  scope :di_domani, -> { where(data_tappa: Date.tomorrow) }
  
  scope :del_giorno, ->(day) { where(data_tappa: day.to_date.all_day) }
  scope :della_settimana, ->(day) { where(data_tappa: day.to_date.beginning_of_week..day.to_date.end_of_week) } 
  scope :del_mese, ->(day) { where(data_tappa: day.beginning_of_month..day.end_of_month) } 
  scope :dell_anno, ->(day) { where(data_tappa: day.beginning_of_year..day.end_of_year) }

  scope :delle_scuole_di, ->(scuole_ids) { where(tappable_id: scuole_ids, tappable_type: 'ImportScuola') }
  scope :della_provincia, ->(provincia) { joins(:import_scuola).where('import_scuole."PROVINCIA" = ?', provincia) }

  scope :attuali, -> { where("data_tappa > ? OR data_tappa IS NULL", Time.zone.now.beginning_of_day) }
  
  scope :programmate, -> { where("data_tappa > ?", Time.zone.now) }  
  
  scope :completate,  -> { where("data_tappa < ?", Time.zone.now.beginning_of_day) }
  scope :da_programmare, -> { where(data_tappa: nil) }

  scope :per_ordine_e_data, -> { joins(:import_scuola).order('import_scuole."PROVINCIA"').order(:ordine, :data_tappa) }
  scope :per_data, -> { order(:data_tappa, :ordine) }
  scope :per_data_desc, -> { order([data_tappa: :desc], :ordine) }
    
  scope :per_comune_e_direzione, -> { joins(:import_scuola).order('import_scuole."PROVINCIA", import_scuole."DESCRIZIONECOMUNE", import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO"') }

  scope :search, ->(search) { 
        joins("INNER JOIN import_scuole ON tappe.tappable_id = import_scuole.id AND tappe.tappable_type = 'ImportScuola'")
        .where('import_scuole."DENOMINAZIONESCUOLA" ILIKE ? OR import_scuole."DESCRIZIONECOMUNE" ILIKE ? OR import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO" ILIKE ? OR tappe."titolo" ILIKE ?', 
        "%#{search}%", "%#{search}%","%#{search}%", "%#{search}%") 
  }

  delegate :latitude, :longitude, :denominazione, to: :tappable

  def attuale?
    data_tappa.nil? || data_tappa >= Time.zone.now.beginning_of_day 
  end

  def oggi?
    data_tappa.to_date == Time.zone.now.to_date
  end
  
  def vuota?
    data_tappa.nil? && titolo.blank?
  end

  def da_ritirare?
    data_tappa.nil? && giro.giro_ritiri?
  end


  def new_giro=(new_giro)
    giro = Current.user.giri.find_or_create_by(titolo: new_giro)
    giro.save
    self.giro = giro
  end


end
