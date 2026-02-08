# == Schema Information
#
# Table name: adozioni
#
#  id                 :uuid             not null, primary key
#  autori             :string
#  codice_isbn        :string
#  consigliato        :boolean          default(FALSE)
#  da_acquistare      :boolean          default(FALSE)
#  disciplina         :string
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
#  index_adozioni_on_account_id                 (account_id)
#  index_adozioni_on_account_id_and_libro_id    (account_id,libro_id)
#  index_adozioni_on_account_id_and_mia         (account_id,mia)
#  index_adozioni_on_classe_id                  (classe_id)
#  index_adozioni_on_classe_id_and_codice_isbn  (classe_id,codice_isbn) UNIQUE
#  index_adozioni_on_import_adozione_id         (import_adozione_id)
#  index_adozioni_on_libro_id                   (libro_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (classe_id => classi.id)
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (libro_id => libri.id)
#
class Adozione < ApplicationRecord
  include AccountScoped

  belongs_to :classe
  belongs_to :libro, optional: true
  belongs_to :import_adozione, optional: true

  has_one :scuola, through: :classe

  validates :codice_isbn, presence: true
  validates :codice_isbn, uniqueness: { scope: :classe_id }

  scope :da_acquistare_flag, -> { where(da_acquistare: true) }
  scope :nuove, -> { where(nuova_adozione: true) }
  scope :consigliate, -> { where(consigliato: true) }
  scope :per_editore, ->(editore) { where(editore: editore) }
  scope :per_disciplina, ->(disciplina) { where(disciplina: disciplina) }
  scope :mie, -> { where(mia: true) }
  scope :per_scuole, ->(scuola_ids) { joins(:classe).where(classi: { scuola_id: scuola_ids }) }

  # Crea da ImportAdozione
  def self.create_from_import(import_adozione, classe:, account: Current.account)
    libro = account.libri.find_by(codice_isbn: import_adozione.CODICEISBN)

    create!(
      account: account,
      classe: classe,
      libro: libro,
      import_adozione: import_adozione,
      codice_isbn: import_adozione.CODICEISBN,
      titolo: import_adozione.TITOLO,
      editore: import_adozione.EDITORE,
      autori: import_adozione.AUTORI,
      disciplina: import_adozione.DISCIPLINA,
      prezzo_cents: (import_adozione.PREZZO.to_s.gsub(',', '.').to_f * 100).to_i,
      nuova_adozione: import_adozione.NUOVAADOZ == "Si",
      da_acquistare: import_adozione.DAACQUIST == "Si",
      consigliato: import_adozione.CONSIGLIATO == "Si"
    )
  end

  # Importa tutte le adozioni per una classe
  def self.import_for_classe(classe)
    return 0 unless classe.codice_ministeriale_origine.present?

    count = 0
    ImportAdozione.where(
      CODICESCUOLA: classe.codice_ministeriale_origine,
      ANNOCORSO: classe.classe_origine,
      SEZIONEANNO: classe.sezione_origine
    ).find_each do |import|
      create_from_import(import, classe: classe)
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
