# == Schema Information
#
# Table name: classi
#
#  id                          :uuid             not null, primary key
#  anno_corso                  :string
#  anno_scolastico             :string
#  classe_origine              :string
#  codice_ministeriale_origine :string
#  combinazione                :string
#  combinazione_origine        :string
#  note                        :text
#  numero_alunni               :integer
#  sezione                     :string
#  sezione_origine             :string
#  stato                       :string           default("attiva"), not null
#  tipo_scuola                 :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :uuid             not null
#  scuola_id                   :uuid             not null
#
# Indexes
#
#  index_classi_attive_on_scuola_anno_sezione_combinazione  (scuola_id,anno_corso,sezione,combinazione) UNIQUE WHERE ((stato)::text = 'attiva'::text)
#  index_classi_on_account_id                               (account_id)
#  index_classi_on_account_id_and_anno_scolastico           (account_id,anno_scolastico)
#  index_classi_on_origine                                  (account_id,codice_ministeriale_origine,classe_origine,sezione_origine)
#  index_classi_on_scuola_id                                (scuola_id)
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
  include Pianificabile
  include ProtectedFromDestroy
  include PgSearch::Model

  def tappa_target
    scuola
  end

  def default_titolo_tappa
    "Classe #{anno_corso}#{sezione}".strip.presence
  end

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
  validates :sezione,
    uniqueness: { scope: %i[scuola_id anno_corso combinazione], conditions: -> { where(stato: "attiva") } },
    allow_blank: true,
    if: -> { stato == "attiva" }

  scope :attive,     -> { where(stato: "attiva") }
  scope :archiviate, -> { where(stato: "archiviata") }
  scope :per_anno,   ->(anno_scolastico) { where(anno_scolastico: anno_scolastico) }

  def self.search_scope(combinazione: nil, provincia: nil, comune: nil, tipo_scuola: nil, anno_corso: nil)
    scope = joins("INNER JOIN scuole ON scuole.id = classi.scuola_id")
      .where(scuole: { id: Current.scuole.select(:id) })

    scope = scope.where("classi.combinazione ILIKE ?", "%#{combinazione}%") if combinazione.present?
    if provincia.present?
      scope = provincia.length <= 2 ? scope.where(scuole: { sigla_provincia: provincia.upcase }) : scope.where(scuole: { provincia: provincia })
    end
    scope = scope.where(scuole: { comune: comune }) if comune.present?
    scope = scope.where(classi: { tipo_scuola: tipo_scuola }) if tipo_scuola.present?
    scope = scope.where(classi: { anno_corso: anno_corso }) if anno_corso.present?

    scope.preload(:scuola).order("scuole.provincia, scuole.comune, scuole.denominazione, classi.anno_corso, classi.sezione")
  end

  delegate :denominazione, to: :scuola, prefix: true
  delegate :cap, :comune, :provincia, :sigla_provincia, :indirizzo, to: :scuola

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

  # Helper per recuperare le adozioni MIUR originali (set ministeriale stabile
  # dell'anno scorso, ex vista ponte import_adozioni = partizione 202526 di miur_adozioni).
  def import_adozioni
    return Miur::Adozione.none unless codice_ministeriale_origine.present?

    Miur::Adozione.per_anno("202526").where(
      codicescuola: codice_ministeriale_origine,
      annocorso: classe_origine,
      sezioneanno: sezione_origine
    )
  end

  # Righe miur_adozioni (sorgente MIUR anno corrente) per questa classe.
  def new_adozioni
    return Miur::Adozione.none unless codice_ministeriale_origine.present?

    Miur::Adozione.per_anno(Miur.anno_corrente).where(
      codicescuola: codice_ministeriale_origine,
      annocorso: classe_origine,
      sezioneanno: sezione_origine,
      combinazione: combinazione_origine
    )
  end

  # Costruisce gli snapshot Adozione per l'anno indicato a partire da miur_adozioni.
  # Idempotente: l'indice unico (classe_id, codice_isbn, anno_scolastico) evita duplicati.
  def costruisci_adozioni!(anno_scolastico:)
    sorgenti = new_adozioni.to_a
    return 0 if sorgenti.empty?

    # Risolve i Libro per ISBN in un'unica query (no N+1), scopata per account
    # come in Adozione.create_from_import (account.libri.find_by(codice_isbn:)).
    isbns = sorgenti.map(&:codiceisbn).compact.uniq
    libro_id_per_isbn = Libro.where(account_id: account_id, codice_isbn: isbns)
      .pluck(:codice_isbn, :id).to_h

    righe = sorgenti.map do |na|
      {
        account_id: account_id,
        classe_id: id,
        libro_id: libro_id_per_isbn[na.codiceisbn],
        codice_isbn: na.codiceisbn,
        titolo: na.titolo,
        editore: na.editore,
        autori: na.autori,
        disciplina: na.disciplina,
        prezzo_cents: ((na.prezzo_euro || 0) * 100).round,
        nuova_adozione: na.nuovaadoz.to_s.match?(/\As/i),
        da_acquistare:  na.daacquist.to_s.match?(/\As/i),
        consigliato:    na.consigliato.to_s.match?(/\As/i),
        anno_scolastico: anno_scolastico,
        anno_corso: anno_corso,
        codicescuola: codice_ministeriale_origine,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    Adozione.insert_all(righe, unique_by: :index_adozioni_on_classe_isbn_anno).count
  end

  def nome_completo
    "#{anno_corso}#{sezione} - #{scuola.denominazione}"
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
