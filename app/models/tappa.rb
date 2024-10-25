# == Schema Information
#
# Table name: tappe
#
#  id            :bigint           not null, primary key
#  data_tappa    :datetime
#  descrizione   :string
#  entro_il      :datetime
#  ordine        :integer
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
#  index_tappe_on_giro_id   (giro_id)
#  index_tappe_on_tappable  (tappable_type,tappable_id)
#  index_tappe_on_user_id   (user_id)
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

  # controllare se filtrare per user_id
  belongs_to :import_scuola, class_name: 'ImportScuola', foreign_key: 'tappable_id'
  def import_scuola
    return unless tappable_type == 'ImportScuola'
    super
  end

  # # belongs_to :cliente, class_name: 'Cliente', foreign_key: 'tappable_id'
  # # def cliente
  # #   return nil unless tappable_type == 'Cliente'
  # #   super
  # # end
  
  scope :di_oggi,   -> { where(data_tappa: Time.zone.now.all_day) }
  scope :di_domani, -> { where(data_tappa: Time.zone.now.tomorrow.all_day) }
  scope :del_giorno, ->(data) { where(data_tappa: data.to_date.all_day) }
  
  scope :delle_scuole_di, ->(scuole_ids) { where(tappable_id: scuole_ids)}
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
