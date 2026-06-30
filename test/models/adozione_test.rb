# == Schema Information
#
# Table name: adozioni
#
#  id                 :uuid             not null, primary key
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
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (libro_id => libri.id)
#
require "test_helper"

class AdozioneTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole, :classi

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  # Sorgente ImportAdozione che combacia con la classe `prima_a`
  # (origine MIIC123456 / 1 / A), anno_scolastico 202526.
  # insert_all per saltare l'autosave del belongs_to :editore (come ImportAdozione.import in produzione).
  def crea_import_adozione(isbn:)
    ImportAdozione.insert_all([{
      CODICESCUOLA: "MIIC123456",
      ANNOCORSO: "1",
      SEZIONEANNO: "A",
      TIPOGRADOSCUOLA: "EE",
      COMBINAZIONE: "MQ",
      CODICEISBN: isbn,
      TITOLO: "Libro Test #{isbn}",
      EDITORE: "Editore Test",
      AUTORI: "Rossi M.",
      DISCIPLINA: "ITALIANO",
      PREZZO: "10,00",
      NUOVAADOZ: "No",
      DAACQUIST: "Si",
      CONSIGLIATO: "No",
      created_at: Time.current,
      updated_at: Time.current
    }])
    ImportAdozione.find_by(CODICEISBN: isbn)
  end

  test "create_from_import stampa anno_scolastico e codicescuola dalla classe" do
    classe = classi(:prima_a) # anno_scolastico 202526, origine MIIC123456
    imp = crea_import_adozione(isbn: "9788899990001")

    adozione = Adozione.create_from_import(imp, classe: classe, account: classe.account)

    assert_equal classe.anno_scolastico, adozione.anno_scolastico
    assert_equal "202526", adozione.anno_scolastico
    assert_equal classe.codice_ministeriale_origine, adozione.codicescuola
    assert_equal "MIIC123456", adozione.codicescuola
  end

  test "import_for_classe è idempotente (doppio run non duplica le adozioni)" do
    classe = classi(:prima_a)
    crea_import_adozione(isbn: "9788899990001")
    crea_import_adozione(isbn: "9788899990002")

    primo = Adozione.import_for_classe(classe)
    assert_equal 2, primo

    assert_no_difference -> { Adozione.where(classe: classe).count } do
      Adozione.import_for_classe(classe)
    end
  end
end
