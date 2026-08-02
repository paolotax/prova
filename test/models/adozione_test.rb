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
#  riportata          :boolean          default(FALSE), not null
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

  test "un'adozione minima e' valida con classe e isbn" do
    classe = classi(:prima_a)

    adozione = Adozione.create!(account: classe.account, classe: classe,
                                codice_isbn: "9788899990001",
                                anno_scolastico: classe.anno_scolastico)

    assert_equal "202526", adozione.anno_scolastico
  end
end
