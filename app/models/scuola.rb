# == Schema Information
#
# Table name: scuole
#
#  id                  :uuid             not null, primary key
#  cap                 :string
#  codice_ministeriale :string
#  comune              :string
#  denominazione       :string
#  email               :string
#  indirizzo           :string
#  note                :text
#  pec                 :string
#  priorita            :integer          default(0)
#  provincia           :string
#  regione             :string
#  stato               :string           default("attiva")
#  telefono            :string
#  tipo_scuola         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :uuid             not null
#  import_scuola_id    :bigint
#
# Indexes
#
#  index_scuole_on_account_id                          (account_id)
#  index_scuole_on_account_id_and_codice_ministeriale  (account_id,codice_ministeriale) UNIQUE
#  index_scuole_on_account_id_and_denominazione        (account_id,denominazione)
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
  include PgSearch::Model

  pg_search_scope :search_all_word,
    against: [:denominazione, :codice_ministeriale, :comune, :provincia],
    using: { tsearch: { any_word: false, prefix: true } }

  belongs_to :import_scuola, optional: true

  has_many :classi, dependent: :destroy
  has_many :adozioni, through: :classi
  has_many :persone, dependent: :destroy

  validates :denominazione, presence: true
  validates :codice_ministeriale, uniqueness: { scope: :account_id }, allow_blank: true

  scope :attive, -> { where(stato: 'attiva') }
  scope :per_provincia, ->(provincia) { where(provincia: provincia) }
  scope :per_comune, ->(comune) { where(comune: comune) }

  # Crea Scuola da ImportScuola
  def self.create_from_import(import_scuola, account: Current.account)
    create!(
      account: account,
      import_scuola: import_scuola,
      codice_ministeriale: import_scuola.CODICESCUOLA,
      denominazione: import_scuola.DENOMINAZIONESCUOLA,
      indirizzo: import_scuola.INDIRIZZOSCUOLA,
      cap: import_scuola.CAPSCUOLA,
      comune: import_scuola.DESCRIZIONECOMUNE,
      provincia: import_scuola.PROVINCIA,
      regione: import_scuola.REGIONE,
      tipo_scuola: import_scuola.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA,
      email: import_scuola.INDIRIZZOEMAILSCUOLA,
      pec: import_scuola.INDIRIZZOPECSCUOLA
    )
  end

  # Trova o crea da ImportScuola
  def self.find_or_create_from_import(import_scuola, account: Current.account)
    find_by(account: account, import_scuola: import_scuola) ||
      find_by(account: account, codice_ministeriale: import_scuola.CODICESCUOLA) ||
      create_from_import(import_scuola, account: account)
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
end
