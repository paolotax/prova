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
require "test_helper"

class ClasseTest < ActiveSupport::TestCase
  fixtures :classi, :scuole, :accounts

  test "tappa_target delegates to scuola" do
    classe = classi(:prima_a_fizzy)
    assert_equal classe.scuola, classe.tappa_target
  end

  test "default_titolo_tappa references the sezione" do
    classe = classi(:prima_a_fizzy)
    assert_match(/Classe/, classe.default_titolo_tappa)
  end
end
