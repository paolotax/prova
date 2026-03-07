# == Schema Information
#
# Table name: classi
#
#  id                          :uuid             not null, primary key
#  anno_corso                  :string
#  classe_origine              :string
#  codice_ministeriale_origine :string
#  combinazione                :string
#  combinazione_origine        :string
#  note                        :text
#  numero_alunni               :integer
#  sezione                     :string
#  sezione_origine             :string
#  tipo_scuola                 :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :uuid             not null
#  scuola_id                   :uuid             not null
#
# Indexes
#
#  index_classi_on_account_id                        (account_id)
#  index_classi_on_origine                           (account_id,codice_ministeriale_origine,classe_origine,sezione_origine)
#  index_classi_on_scuola_anno_sezione_combinazione  (scuola_id,anno_corso,sezione,combinazione) UNIQUE
#  index_classi_on_scuola_id                         (scuola_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (scuola_id => scuole.id)
#
class Classe < ApplicationRecord
  include AccountScoped
  include Appuntabile
  include HasEntries
  include ProtectedFromDestroy
  include PgSearch::Model

  # Custom search that handles both class codes (2A) and scuola names (Dante)
  # Splits query into words and ensures ALL words match somewhere across fields
  scope :search_all_word, ->(query) {
    return none if query.blank?

    words = query.to_s.split(/\s+/).reject(&:blank?)
    return none if words.empty?

    scope = joins(:scuola)

    # Each word must match at least one field
    words.each do |word|
      sanitized = "%#{sanitize_sql_like(word)}%"
      scope = scope.where(
        "classi.anno_corso || classi.sezione ILIKE :q OR scuole.denominazione ILIKE :q OR scuole.comune ILIKE :q",
        q: sanitized
      )
    end

    scope
  }

  belongs_to :scuola

  has_many :persona_classi, dependent: :destroy
  has_many :persone, through: :persona_classi

  has_many :adozioni, dependent: :destroy
  has_many :consegne_saggio, through: :adozioni
  has_many :saggi, class_name: "Saggio", as: :destinatario, dependent: :nullify
  has_many :documenti, as: :clientable

  validates :anno_corso, presence: true
  validates :sezione, uniqueness: { scope: [:scuola_id, :anno_corso, :combinazione] }, allow_blank: true

  scope :per_anno, ->(anno) { where(anno_corso: anno) }

  delegate :denominazione, to: :scuola, prefix: true
  delegate :comune, :provincia, to: :scuola

  # Per clientable_label_tag: "1A Ada Negri"
  def denominazione
    "#{anno_corso}#{sezione} #{scuola&.denominazione}"
  end

  # Crea Classe da Views::Classe
  def self.create_from_view(view_classe, scuola:, account: Current.account)
    create!(
      account: account,
      scuola: scuola,
      anno_corso: view_classe.classe,
      sezione: view_classe.sezione,
      combinazione: view_classe.combinazione,
      tipo_scuola: view_classe.tipo_scuola,
      codice_ministeriale_origine: view_classe.codice_ministeriale,
      classe_origine: view_classe.classe,
      sezione_origine: view_classe.sezione,
      combinazione_origine: view_classe.combinazione
    )
  end

  # Trova o crea da Views::Classe
  def self.find_or_create_from_view(view_classe, scuola:, account: Current.account)
    find_by(
      account: account,
      scuola: scuola,
      anno_corso: view_classe.classe,
      sezione: view_classe.sezione,
      combinazione: view_classe.combinazione
    ) || create_from_view(view_classe, scuola: scuola, account: account)
  end

  # Helper per recuperare le ImportAdozioni originali
  def import_adozioni
    return ImportAdozione.none unless codice_ministeriale_origine.present?

    ImportAdozione.where(
      CODICESCUOLA: codice_ministeriale_origine,
      ANNOCORSO: classe_origine,
      SEZIONEANNO: sezione_origine
    )
  end

  def nome_completo
    "#{scuola.denominazione} - #{anno_corso}#{sezione}"
  end

  def nome_breve
    "#{anno_corso}#{sezione}"
  end

  def classe_e_sezione
    "#{anno_corso} #{sezione&.titleize}"
  end

  def to_s
    nome_breve
  end

  def to_combobox_display
    nome_completo
  end

  private

  def entry_appunto_ids
    appunti.published.pluck(:id).map(&:to_s)
  end

  def entry_documento_ids
    Documento.where(clientable: self).pluck(:id).map(&:to_s)
  end
end
