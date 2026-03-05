# == Schema Information
#
# Table name: scuole
#
#  id                  :uuid             not null, primary key
#  adozioni_count      :integer          default(0), not null
#  area                :string
#  cap                 :string
#  classi_count        :integer          default(0), not null
#  codice_ministeriale :string
#  comune              :string
#  denominazione       :string
#  email               :string
#  grado               :string
#  indirizzo           :string
#  latitude            :float
#  longitude           :float
#  mie_adozioni_count  :integer          default(0), not null
#  note                :text
#  pec                 :string
#  posizione           :integer          default(0)
#  priorita            :integer          default(0)
#  provincia           :string
#  regione             :string
#  sigla_provincia     :string(2)
#  stato               :string           default("attiva")
#  telefono            :string
#  tipo_scuola         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :uuid             not null
#  direzione_id        :uuid
#  import_scuola_id    :bigint
#
# Indexes
#
#  index_scuole_on_account_id                          (account_id)
#  index_scuole_on_account_id_and_codice_ministeriale  (account_id,codice_ministeriale) UNIQUE
#  index_scuole_on_account_id_and_denominazione        (account_id,denominazione)
#  index_scuole_on_account_id_and_direzione_id         (account_id,direzione_id)
#  index_scuole_on_account_id_and_posizione            (account_id,posizione)
#  index_scuole_on_account_provincia_grado             (account_id,provincia,grado)
#  index_scuole_on_import_scuola_id                    (import_scuola_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#
class Scuola < ApplicationRecord
  include AccountScoped
  include Appuntabile
  include HasEntries
  include Navigable
  include ProtectedFromDestroy
  include PgSearch::Model


  pg_search_scope :search_all_word,
    against: [:denominazione, :codice_ministeriale, :comune, :provincia],
    using: { tsearch: { any_word: false, prefix: true } }

  belongs_to :import_scuola, optional: true
  belongs_to :direzione, class_name: "Scuola", optional: true
  has_many :plessi, class_name: "Scuola", foreign_key: :direzione_id, dependent: :nullify

  has_many :membership_scuole, class_name: "Accounts::MembershipScuola", dependent: :destroy
  has_many :memberships, through: :membership_scuole

  has_many :classi, dependent: :destroy
  has_many :adozioni, through: :classi
  has_many :persone, dependent: :destroy
  has_many :documenti, as: :clientable
  has_many :sconti, as: :scontabile, dependent: :destroy
  has_many :tappe, as: :tappable
  has_many :saggi, dependent: :destroy

  before_validation :normalize_fields
  after_update_commit :propagate_area_to_plessi, if: :saved_change_to_area?

  validates :denominazione, presence: true
  validates :codice_ministeriale, uniqueness: { scope: :account_id }, allow_blank: true

  scope :attive, -> { where(stato: 'attiva') }
  scope :per_posizione, -> { order(:posizione) }
  scope :per_provincia, ->(provincia) { where(provincia: provincia) }
  scope :per_comune, ->(comune) { where(comune: comune) }

  # Scuole che fungono da direzione (hanno almeno un plesso)
  scope :direzioni, -> { where(id: unscoped.select(:direzione_id).where.not(direzione_id: nil)) }
  # Scuole che puntano a una direzione
  scope :con_direzione, -> { where.not(direzione_id: nil) }
  # Scuole isolate (né direzioni né plessi)
  scope :senza_direzione, -> {
    where(direzione_id: nil)
      .where.not(id: unscoped.select(:direzione_id).where.not(direzione_id: nil))
  }

  # Risolve un param stringa in un array di scuole
  # Formati: "prov:MI", "dir:<uuid>:<grado>", "group:MI:primaria", "<uuid>"
  def self.resolve_from_param(param, scope: Current.account.scuole)
    case param
    when /\Aprov:(.+)\z/
      scope.where(provincia: $1).to_a
    when /\Adir:(.+):(.+)\z/
      direzione = scope.find($1)
      [direzione] + direzione.plessi.where(grado: $2).to_a
    when /\Agroup:(.+):(.+)\z/
      plessi = scope.where(provincia: $1, grado: $2)
      dir_ids = plessi.where.not(direzione_id: nil).distinct.pluck(:direzione_id)
      direzioni = scope.where(id: dir_ids)
      (plessi.to_a + direzioni.to_a).uniq
    else
      [scope.find(param)]
    end
  end

  # Crea Scuola da ImportScuola
  def self.create_from_import(import_scuola, account: Current.account)
    direzione = resolve_direzione(import_scuola, account: account)
    create!(
      account: account,
      import_scuola: import_scuola,
      direzione: direzione,
      codice_ministeriale: import_scuola.CODICESCUOLA,
      denominazione: import_scuola.DENOMINAZIONESCUOLA,
      indirizzo: import_scuola.INDIRIZZOSCUOLA,
      cap: import_scuola.CAPSCUOLA,
      comune: import_scuola.DESCRIZIONECOMUNE,
      provincia: import_scuola.PROVINCIA,
      regione: import_scuola.REGIONE,
      tipo_scuola: import_scuola.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA,
      email: import_scuola.INDIRIZZOEMAILSCUOLA,
      pec: import_scuola.INDIRIZZOPECSCUOLA,
      grado: TipoScuola.find_by(tipo: import_scuola.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA)&.grado,
      latitude: import_scuola.latitude,
      longitude: import_scuola.longitude
    )
  end

  # Cerca/crea la scuola-direzione se il plesso ha CODICEISTITUTORIFERIMENTO diverso
  def self.resolve_direzione(import_scuola, account:)
    codice_rif = import_scuola.CODICEISTITUTORIFERIMENTO
    return nil if codice_rif.blank? || codice_rif == import_scuola.CODICESCUOLA

    import_dir = ImportScuola.find_by(CODICESCUOLA: codice_rif)
    return nil unless import_dir

    find_or_create_from_import(import_dir, account: account)
  end

  # Trova o crea da ImportScuola
  def self.find_or_create_from_import(import_scuola, account: Current.account)
    find_by(account: account, import_scuola: import_scuola) ||
      find_by(account: account, codice_ministeriale: import_scuola.CODICESCUOLA) ||
      create_from_import(import_scuola, account: account)
  end

  def direzione?
    plessi.any?
  end

  def deletable?
    !classi.exists? &&
      !persone.exists? &&
      !documenti.exists? &&
      !tappe.exists? &&
      !Appunto.where(appuntabile: self).exists?
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def indirizzo_navigator
    [indirizzo, cap, comune, provincia].compact_blank.join(" ")
  end

  def to_s
    denominazione
  end

  def to_combobox_display
    "#{denominazione} - #{comune}"
  end

  def indirizzo_completo
    [indirizzo, cap, comune, provincia].compact.join(', ')
  end

  def indirizzo_formattato
    [indirizzo, [cap, comune].compact.join(' '), provincia].compact.join("\n")
  end

  private

  def normalize_fields
    self.tipo_scuola = tipo_scuola.upcase if tipo_scuola.present?
    self.regione = regione.upcase if regione.present?
    self.provincia = provincia.upcase if provincia.present?
    self.pec = nil if pec.present? && pec.downcase.include?("non disponibil")
  end

  def propagate_area_to_plessi
    plessi.update_all(area: area) if plessi.any?
  end

  private

  def entry_appunto_ids
    classe_ids = classi.pluck(:id)
    (appunti.published.pluck(:id) +
     Appunto.published.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).pluck(:id))
    .map(&:to_s)
  end

  def entry_documento_ids
    classe_ids = classi.pluck(:id)
    (Documento.where(clientable: self).pluck(:id) +
     Documento.where(clientable_type: "Classe", clientable_id: classe_ids).pluck(:id))
    .map(&:to_s)
  end
end
