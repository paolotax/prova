# == Schema Information
#
# Table name: tappe
#
#  id            :uuid             not null, primary key
#  data_tappa    :date
#  descrizione   :string
#  entro_il      :datetime
#  position      :integer          not null
#  tappable_type :string           not null
#  titolo        :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid             not null
#  giro_id       :bigint
#  tappable_id   :uuid
#  user_id       :bigint
#
# Indexes
#
#  index_tappe_on_account_id                           (account_id)
#  index_tappe_on_giro_id                              (giro_id)
#  index_tappe_on_tappable                             (tappable_type,tappable_id)
#  index_tappe_on_user_id                              (user_id)
#  index_tappe_on_user_id_and_data_tappa_and_position  (user_id,data_tappa,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (giro_id => giri.id)
#  fk_rails_...  (user_id => users.id)
#

class Tappa < ApplicationRecord
  include AccountScoped
  include Entryable
  # Closeable rimosso: ora usa Entry::Closeable via Entryable delegation

  belongs_to :user
  
  #belongs_to :giro, optional: true, touch: true
  has_many :tappa_giri, dependent: :destroy
  has_many :giri, through: :tappa_giri, source: :giro

  belongs_to :tappable, polymorphic: true

  has_many :bolle_visione

  # Virtual attribute per combobox multi-entità
  # Formato: "Scuola:uuid" o "Cliente:id"
  def tappable_value
    return nil unless tappable.present?
    tappable.to_appuntabile_value
  end

  def tappable_value=(value)
    return if value.blank?

    klass, id = Appuntabile.parse_appuntabile_value(value)
    if klass && id
      begin
        self.tappable = klass.find_by(id: id)
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.warn "Invalid tappable_value format: #{value} - #{e.message}"
        nil
      end
    end
  end

  accepts_nested_attributes_for :giri
 
  after_update_commit :manage_entry_on_data_change, if: :saved_change_to_data_tappa?

  positioned on: [:user, :data_tappa], column: :position

  
  scope :ultima, -> { order(created_at: :desc).first }
  
  scope :tappe_future, -> { order(data_tappa: :asc).where("data_tappa >= ?", Date.today) }
  scope :tappe_passate, -> { order(data_tappa: :desc).where("data_tappa < ?", Date.today) }
  
  scope :con_data_tappa, -> { where.not(data_tappa: nil) }
  
  scope :di_oggi,   -> { where(data_tappa: Date.today) }
  scope :di_domani, -> { where(data_tappa: Date.tomorrow) }
  
  scope :del_giorno, ->(day) { where(data_tappa: day.to_date.all_day) }
  scope :della_settimana, ->(day) { where(data_tappa: day.to_date.beginning_of_week..day.to_date.end_of_week) } 
  scope :del_mese, ->(day) { where(data_tappa: day.beginning_of_month..day.end_of_month) } 
  scope :dell_anno, ->(day) { where(data_tappa: day.beginning_of_year..day.end_of_year) }

  scope :delle_scuole_di, ->(scuole_ids) { where(tappable_id: scuole_ids, tappable_type: 'Scuola') }
  scope :della_provincia, ->(provincia) { joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id AND tappe.tappable_type = 'Scuola'").where(scuole: { provincia: provincia }) }
  scope :dell_area, ->(area) { joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id AND tappe.tappable_type = 'Scuola'").where(scuole: { area: area }) }

  scope :attuali, -> { where("data_tappa > ? OR data_tappa IS NULL", Time.zone.now.beginning_of_day) }
  
  scope :programmate, -> { where("data_tappa >= ?", Time.zone.now.beginning_of_day) }  
  
  scope :completate,  -> { where("data_tappa < ?", Time.zone.now.beginning_of_day) }
  scope :da_programmare, -> { where(data_tappa: nil) }

  scope :per_ordine_e_data, -> {
    joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id AND tappe.tappable_type = 'Scuola'")
    .order('scuole.posizione') }
  
  scope :per_data, -> { order(:data_tappa, :position) }
  scope :per_data_desc, -> { order(data_tappa: :desc, position: :desc) }
    
  scope :per_comune_e_direzione, -> {
    joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id AND tappe.tappable_type = 'Scuola'")
    .order('scuole.provincia, scuole.comune, scuole.denominazione') }

  scope :search, ->(search) {
    joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id AND tappe.tappable_type = 'Scuola'")
    .where('scuole.denominazione ILIKE ? OR scuole.comune ILIKE ? OR tappe.titolo ILIKE ?',
      "%#{search}%", "%#{search}%", "%#{search}%")
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
    #data_tappa.nil? && giro.giro_ritiri?
  end

  private

  def should_auto_create_entry?
    data_tappa.present? && data_tappa <= Date.today
  end

  def manage_entry_on_data_change
    if data_tappa.present? && data_tappa <= Date.today
      ensure_entry! unless entry.present?
    elsif entry.present?
      # Use delete (not destroy) to avoid Entry's delegated_type dependent: :destroy
      # which would cascade back and delete this Tappa
      e = entry
      e.goldness&.delete
      e.closure&.delete
      e.not_now&.delete
      e.events.delete_all
      e.delete
      reload_entry
    end
  end

  def self.ultima_tappa_passata
    order(data_tappa: :desc).where("data_tappa < ?", Date.today).first
  end


  def new_giro=(new_giro)
    giro = Current.user.giri.find_or_create_by(titolo: new_giro)
    giro.save
    self.giro = giro
  end


end
