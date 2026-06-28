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
#  email_dominio       :string
#  email_pattern       :string
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
  include Pianificabile
  include ProtectedFromDestroy
  include Saldabile
  include Scartabile
  include HasDisponibilita
  include PgSearch::Model

  geocoded_by :address
  after_validation :geocode, if: ->(obj) { obj.indirizzo_changed? || obj.cap_changed? || obj.comune_changed? || obj.provincia_changed? }

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
  has_many :bolle_visione

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

  # Raggruppa una collezione di scuole in { provincia => { area => { direzione => [plessi] } } }
  def self.to_gerarchia(scuole)
    scuole.each_with_object({}) do |scuola, result|
      prov = scuola.provincia.presence || "Senza provincia"
      area = scuola.area.presence || "Senza area"
      dir_label = scuola.direzione&.denominazione || "Autonome"

      result[prov] ||= {}
      result[prov][area] ||= {}
      result[prov][area][dir_label] ||= []
      result[prov][area][dir_label] << scuola
    end
  end

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

  def address
    [indirizzo, cap, comune, provincia].compact_blank.join(" ")
  end

  # Promuovibile all'anno successivo (passaggio anno EE) quando l'anagrafe MIUR
  # del nuovo anno è disponibile e la scuola non è ancora stata fatta scorrere.
  def promuovibile?(anno_target = NewScuola.maximum(:anno_scolastico))
    return false if anno_target.blank?
    return false if classi.attive.maximum(:anno_scolastico).to_s >= anno_target
    NewScuola.where(codice_scuola: codice_ministeriale, anno_scolastico: anno_target).exists?
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

  EMAIL_PATTERNS = {
    "nome.cognome" => "nome.cognome",
    "n.cognome" => "n.cognome",
    "cognome.nome" => "cognome.nome",
    "nomecognome" => "nomecognome",
    "cognomenome" => "cognomenome"
  }.freeze

  def genera_email_docente(nome, cognome)
    pattern = email_pattern.presence || direzione&.email_pattern
    dominio = email_dominio.presence || direzione&.email_dominio
    return nil if pattern.blank? || dominio.blank?

    nome_norm = normalize_email_part(nome)
    cognome_norm = normalize_email_part(cognome)
    return nil if nome_norm.blank? || cognome_norm.blank?

    local_part = case pattern
    when "nome.cognome" then "#{nome_norm}.#{cognome_norm}"
    when "n.cognome" then "#{nome_norm[0]}.#{cognome_norm}"
    when "cognome.nome" then "#{cognome_norm}.#{nome_norm}"
    when "nomecognome" then "#{nome_norm}#{cognome_norm}"
    when "cognomenome" then "#{cognome_norm}#{nome_norm}"
    else pattern
    end

    "#{local_part}@#{dominio}"
  end

  # Scorrimento d'anno per la PRIMARIA (EE). Idempotente sul target `a`.
  # spostamenti_insegnanti: { persona_classe_uscente_id => sezione_destinazione_string }
  def promuovi_primaria!(da:, a:, spostamenti_insegnanti: {})
    transaction do
      unless classi.attive.per_anno(a).exists?
        # EE-only: anno_corso 1–5, numerico; gradi non numerici (licei 45/123) su un futuro path medie/superiori, non qui.
        classi.attive.per_anno(da).order(Arel.sql("anno_corso::int DESC")).each do |classe|
          if classe.anno_corso.to_i >= 5
            classe.update!(stato: "archiviata")
          else
            nuovo = (classe.anno_corso.to_i + 1).to_s
            classe.update!(
              anno_corso: nuovo,
              classe_origine: nuovo,
              anno_scolastico: a,
              codice_ministeriale_origine: codice_ministeriale
            )
          end
        end

        classi.attive.per_anno(a).find_each { |c| c.costruisci_adozioni!(anno_scolastico: a) }
        crea_classi_prime!(anno_scolastico: a)
      end

      applica_spostamenti_insegnanti!(spostamenti_insegnanti, a: a)
    end

    UpdateScuolaMieAdozioniJob.perform_later(account, scuola_id: id)
    UpdateScuoleCountersJob.perform_later(account, provincia: provincia)

    # Rinfresca (morph) le pagine scuola aperte: la show mostra le nuove classi/adozioni.
    Turbo::StreamsChannel.broadcast_refresh_to(account, "scuole")
  end

  private

  def crea_classi_prime!(anno_scolastico:)
    gruppi = NewAdozione
      .where(codicescuola: codice_ministeriale, annocorso: "1", tipogradoscuola: "EE")
      .group(:sezioneanno, :combinazione).count.keys

    gruppi.each do |sezione, combinazione|
      classe = classi.find_or_create_by!(
        anno_corso: "1", sezione: sezione, combinazione: combinazione,
        anno_scolastico: anno_scolastico, stato: "attiva"
      ) do |c|
        c.account_id = account_id
        c.tipo_scuola = "EE"
        c.codice_ministeriale_origine = codice_ministeriale
        c.classe_origine = "1"
        c.sezione_origine = sezione
        c.combinazione_origine = combinazione
      end
      classe.costruisci_adozioni!(anno_scolastico: anno_scolastico)
    end
  end

  def applica_spostamenti_insegnanti!(mappa, a:)
    return if mappa.blank?
    mappa.each do |persona_classe_id, sezione_destinazione|
      pc = PersonaClasse.joins(:classe).where(classi: { account_id: account_id }).find_by(id: persona_classe_id)
      next unless pc && sezione_destinazione.present?
      # NB: se una sezione copre piu combinazioni esistono piu prime omonime; find_by ne sceglie la prima (accettabile per EE).
      destinazione = classi.attive.find_by(anno_corso: "1", sezione: sezione_destinazione, anno_scolastico: a)
      next unless destinazione
      PersonaClasse.find_or_create_by!(persona_id: pc.persona_id, classe_id: destinazione.id) do |nuovo|
        nuovo.materia = pc.materia
      end
    end
  end

  def normalize_email_part(str)
    return "" if str.blank?
    str.unicode_normalize(:nfkd)
       .gsub(/[\u0300-\u036f]/, "")
       .gsub(/[^a-zA-Z]/, "")
       .downcase
  end

  def normalize_fields
    self.tipo_scuola = tipo_scuola.upcase if tipo_scuola.present?
    self.regione = regione.upcase if regione.present?
    self.provincia = provincia.upcase if provincia.present?
    self.pec = nil if pec.present? && pec.downcase.include?("non disponibil")
  end

  def propagate_area_to_plessi
    plessi.update_all(area: area) if plessi.any?
  end

  def entry_appunto_ids
    classe_ids = classi.pluck(:id)
    persona_ids = persone.pluck(:id)
    (appunti.published.pluck(:id) +
     Appunto.published.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).pluck(:id) +
     Appunto.published.where(appuntabile_type: "Persona", appuntabile_id: persona_ids).pluck(:id))
    .map(&:to_s)
  end

  def entry_documento_ids
    classe_ids = classi.pluck(:id)
    persona_ids = persone.pluck(:id)
    (Documento.where(clientable: self).pluck(:id) +
     Documento.where(clientable_type: "Classe", clientable_id: classe_ids).pluck(:id) +
     Documento.where(clientable_type: "Persona", clientable_id: persona_ids).pluck(:id))
    .map(&:to_s)
  end

  def entry_tappa_ids
    tappe.pluck(:id).map(&:to_s)
  end
end
