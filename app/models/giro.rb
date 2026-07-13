# == Schema Information
#
# Table name: giri
#
#  id            :bigint           not null, primary key
#  color         :string           default("var(--color-card-default)")
#  conditions    :text
#  descrizione   :string
#  finito_il     :datetime
#  iniziato_il   :datetime
#  stato         :string
#  tipo_giro     :string
#  titolo        :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid             not null
#  collana_id    :uuid
#  propaganda_id :uuid
#  user_id       :bigint           not null
#
# Indexes
#
#  index_giri_on_account_id     (account_id)
#  index_giri_on_collana_id     (collana_id)
#  index_giri_on_propaganda_id  (propaganda_id)
#  index_giri_on_user_id        (user_id)
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
  belongs_to :propaganda, optional: true

  has_many :tappa_giri, dependent: :destroy
  has_many :tappe, through: :tappa_giri

  # tappe.giro_id è legacy (rimpiazzato dal join tappa_giri) ma il FK in DB
  # esiste ancora: nullify per poter distruggere il giro
  has_many :tappe_legacy, class_name: "Tappa", foreign_key: :giro_id, dependent: :nullify

  # Le entry del kanban referenziano il giro con un FK: senza nullify la
  # destroy del giro viola il vincolo (entries.giro_id)
  has_many :entries, dependent: :nullify

  TIPI_GIRO = %w[kit_adozioni collane ritiro_collane consegne visite].freeze

  scope :attivi, -> { where("finito_il IS NULL OR finito_il >= ?", Date.current.beginning_of_year) }

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
    scuole = Scuola.where(id: Array(school_ids).map(&:to_s)).index_by { |s| s.id.to_s }
    Array(school_ids).map(&:to_s).each do |school_id|
      scuola = scuole[school_id]
      next unless scuola
      Tappa.merge_or_create_in_giro!(user: user, tappable: scuola, giro: self, account: account)
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
    tappe_correnti = tappe.includes(:tappa_giri).to_a
    count = 0

    tappe_correnti.each do |tappa|
      link = tappa.tappa_giri.find { |tg| tg.giro_id == id }
      next unless link

      if tappa.tappa_giri.size > 1
        link.destroy!
      else
        tappa.destroy!
      end
      count += 1
    end

    tappe.reset
    count
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
