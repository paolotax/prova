# == Schema Information
#
# Table name: adozioni
#
#  id                 :uuid             not null, primary key
#  anno_corso         :string
#  anno_scolastico    :string
#  autori             :string
#  codice_isbn        :string
#  codicescuola       :string
#  consigliato        :boolean          default(FALSE)
#  da_acquistare      :boolean          default(FALSE)
#  disciplina         :string
#  disdetta           :boolean          default(FALSE), not null
#  editore            :string
#  mia                :boolean          default(FALSE), not null
#  note               :text
#  numero_copie       :integer          default(0)
#  nuova_adozione     :boolean          default(FALSE)
#  prezzo_cents       :integer          default(0)
#  titolo             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :uuid             not null
#  classe_id          :uuid             not null
#  import_adozione_id :bigint
#  libro_id           :bigint
#
# Indexes
#
#  index_adozioni_on_account_classe_da_acquistare    (account_id,classe_id) WHERE (da_acquistare = true)
#  index_adozioni_on_account_id                      (account_id)
#  index_adozioni_on_account_id_and_anno_scolastico  (account_id,anno_scolastico)
#  index_adozioni_on_account_id_and_libro_id         (account_id,libro_id)
#  index_adozioni_on_account_id_and_mia              (account_id,mia)
#  index_adozioni_on_classe_id                       (classe_id)
#  index_adozioni_on_classe_isbn_anno                (classe_id,codice_isbn,anno_scolastico) UNIQUE
#  index_adozioni_on_import_adozione_id              (import_adozione_id)
#  index_adozioni_on_libro_id                        (libro_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (classe_id => classi.id)
#  fk_rails_...  (libro_id => libri.id)
#
class Adozione < ApplicationRecord
  include AccountScoped

  belongs_to :classe
  belongs_to :libro, optional: true
  belongs_to :import_adozione, optional: true

  has_one :scuola, through: :classe

  has_many :consegne_saggio, class_name: "ConsegnaSaggio", dependent: :destroy
  has_many :saggi, -> { where(tipo: "saggio") }, class_name: "ConsegnaSaggio"
  has_many :kit_consegne, -> { where(tipo: "kit") }, class_name: "ConsegnaSaggio"
  has_many :seguiti, -> { where(tipo: "seguito") }, class_name: "ConsegnaSaggio"

  validates :codice_isbn, presence: true
  validates :codice_isbn, uniqueness: { scope: :classe_id }

  scope :da_acquistare_flag, -> { where(da_acquistare: true) }
  scope :nuove, -> { where(nuova_adozione: true) }
  scope :consigliate, -> { where(consigliato: true) }
  scope :per_editore, ->(editore) { where(editore: editore) }
  scope :per_disciplina, ->(disciplina) { where(disciplina: disciplina) }
  scope :mie, -> { where(mia: true) }
  scope :mie_attive, -> { where(mia: true, disdetta: false) }
  scope :mie_disdette, -> { where(mia: true, disdetta: true) }
  scope :da_acquistare, -> { where(da_acquistare: true) }
  scope :per_scuole, ->(scuola_ids) { joins(:classe).where(classi: { scuola_id: scuola_ids }) }
  # Solo le adozioni dello snapshot dell'anno corrente della loro classe (esclude gli anni passati).
  scope :correnti, -> { joins(:classe).where("adozioni.anno_scolastico IS NOT DISTINCT FROM classi.anno_scolastico") }
  scope :adozioni_144, -> {
    joins(:classe).where(
      classi: { anno_corso: Stats::Calcolo144::CLASSI_144 },
      disciplina: Stats::Calcolo144.discipline_names
    )
  }
  scope :scorrimenti_235, -> {
    joins(:classe).where(classi: { anno_corso: Stats::Calcolo144::CLASSI_235 })
  }

  delegate :classe_e_sezione, :combinazione, to: :classe, allow_nil: true

  def kit
    kit_consegne
  end

  def mia_adozione?
    mia?
  end

  def da_acquistare?
    da_acquistare
  end

  def classe_e_sezione_e_disciplina
    "#{classe&.classe_e_sezione} #{disciplina&.downcase}"
  end

  # Crea da una riga ministeriale (Miur::Adozione, partizione 202526)
  def self.create_from_import(import_adozione, classe:, account: Current.account)
    libro = account.libri.find_by(codice_isbn: import_adozione.codiceisbn)

    create!(
      account: account,
      classe: classe,
      libro: libro,
      import_adozione_id: import_adozione.id,
      anno_scolastico: classe.anno_scolastico,
      anno_corso: classe.anno_corso,
      codicescuola: classe.codice_ministeriale_origine,
      codice_isbn: import_adozione.codiceisbn,
      titolo: import_adozione.titolo,
      editore: import_adozione.editore,
      autori: import_adozione.autori,
      disciplina: import_adozione.disciplina,
      prezzo_cents: (import_adozione.prezzo.to_s.gsub(',', '.').to_f * 100).to_i,
      nuova_adozione: import_adozione.nuovaadoz == "Si",
      da_acquistare: import_adozione.daacquist == "Si",
      consigliato: import_adozione.consigliato == "Si"
    )
  end

  # Importa tutte le adozioni per una classe
  def self.import_for_classe(classe)
    return 0 unless classe.codice_ministeriale_origine.present?

    count = 0
    Miur::Adozione.per_anno("202526").where(
      codicescuola: classe.codice_ministeriale_origine,
      annocorso: classe.classe_origine,
      sezioneanno: classe.sezione_origine
    ).find_each do |import|
      create_from_import(import, classe: classe, account: classe.account)
      count += 1
    rescue ActiveRecord::RecordInvalid
      # già importata, skip
    end
    count
  end

  def prezzo
    prezzo_cents / 100.0
  end

  def importo
    prezzo_cents * numero_copie / 100.0
  end

  def to_s
    titolo
  end
end
