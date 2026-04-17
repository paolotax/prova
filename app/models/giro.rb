# == Schema Information
#
# Table name: giri
#
#  id          :bigint           not null, primary key
#  color       :string           default("var(--color-card-default)")
#  conditions  :text
#  descrizione :string
#  finito_il   :datetime
#  iniziato_il :datetime
#  stato       :string
#  tipo_giro   :string
#  titolo      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :uuid             not null
#  collana_id  :uuid
#  user_id     :bigint           not null
#
# Indexes
#
#  index_giri_on_account_id  (account_id)
#  index_giri_on_collana_id  (collana_id)
#  index_giri_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#

class Giro < ApplicationRecord
  include AccountScoped

  belongs_to :user
  belongs_to :collana, optional: true

  has_many :tappa_giri
  has_many :tappe, through: :tappa_giri

  TIPI_GIRO = %w[kit_adozioni collane ritiro_collane consegne visite].freeze

  validates :titolo, presence: true
  validates :tipo_giro, inclusion: { in: TIPI_GIRO }, allow_nil: true

  before_validation :set_default_finito_il

  broadcasts_to ->(giro) { [giro.user, "giri"] }, target: "giri-lista", inserts_by: :append

  serialize :conditions, coder: YAML
  before_save :normalize_arrays

  def to_combobox_display
    titolo
  end

  def can_delete?
    tappe.empty?
  end

  def next
    self.class.where("id > ? and user_id = ?", id, user_id).first
  end

  def previous
    self.class.where("id < ? and user_id = ?", id, user_id).last
  end

  def giro_ritiri?
    titolo == "Ritiri"
  end

  def filter_schools(schools)
    schools.to_a
  end

  def settimane
    return [] unless iniziato_il && finito_il
    dal = iniziato_il.to_date
    al  = finito_il.to_date
    return [] if al < dal || (al - dal).to_i > 365

    (dal.beginning_of_week..al.end_of_week)
      .group_by(&:beginning_of_week)
      .values
  end

  def giorni_timeline(tappe_per_giorno)
    oggi = Date.current
    tappe_per_giorno.transform_keys { |k| k.to_date }.sort.map do |date, tappe|
      { date: date, count: tappe.size, today: date == oggi, past: date < oggi }
    end
  end

  def tappe_per_giorno
    tappe.con_data_tappa
      .includes(:tappable, :giri)
      .group_by(&:data_tappa)
  end

  def tappe_totali
    tappe.size
  end

  def tappe_completate
    tappe.completate.size
  end

  def scuole_disponibili_per_tappe
    existing_ids = tappe.where(tappable_type: "Scuola").pluck(:tappable_id).map(&:to_s)
    Current.scuole
      .where.not(id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil))
      .where.not(id: existing_ids)
      .includes(:direzione)
      .order(:posizione)
  end

  def genera_tappe_per(school_ids:, user:)
    Array(school_ids).map(&:to_s).each do |school_id|
      tappa = user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: school_id,
        account: account,
        data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: self)
    end.size
  end

  def copia_tappe_da(source:, user:, schedule_dates: false)
    existing_codes = tappe.where(tappable_type: "Scuola")
      .joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id")
      .pluck("scuole.codice_ministeriale").compact.to_set

    scuole_by_codice = Current.scuole.where.not(codice_ministeriale: [nil, ""])
      .index_by(&:codice_ministeriale)

    schedule = schedule_dates && source.iniziato_il.present? && iniziato_il.present?
    if schedule
      source_start = source.iniziato_il.to_date.beginning_of_week
      dest_start = iniziato_il.to_date.beginning_of_week
    end

    source_tappe = source.tappe.where(tappable_type: "Scuola")
      .joins("INNER JOIN scuole ON tappe.tappable_id = scuole.id")
      .select("tappe.*, scuole.codice_ministeriale AS source_codice")

    count = 0
    max_date = nil

    source_tappe.each do |source_tappa|
      codice = source_tappa.source_codice
      next if codice.blank?
      next if existing_codes.include?(codice)

      target_scuola = scuole_by_codice[codice]
      next unless target_scuola

      new_date = nil
      if schedule && source_tappa.data_tappa.present?
        offset = source_tappa.data_tappa - source_start
        new_date = dest_start + offset
        max_date = [max_date, new_date].compact.max
      end

      tappa = user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: target_scuola.id,
        account: account,
        data_tappa: new_date
      )
      tappa.tappa_giri.create!(giro: self)
      existing_codes << codice
      count += 1
    end

    if schedule && max_date && (finito_il.nil? || max_date > finito_il.to_date)
      update!(finito_il: max_date.end_of_week)
    end

    count
  end

  def svuota_tappe!
    to_destroy = tappe.to_a
    to_destroy.each(&:destroy!)
    tappe.reset
    to_destroy.size
  end

  private

  def normalize_arrays
    self.conditions = [] if conditions.nil?
  end

  def set_default_finito_il
    return unless iniziato_il.present?
    return if finito_il.present? && finito_il >= iniziato_il

    self.finito_il = iniziato_il + 4.weeks
  end

end
