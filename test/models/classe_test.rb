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
require "test_helper"

class ClasseTest < ActiveSupport::TestCase
  # miur/scuole popola l'anagrafe miur_scuole così Miur.anno_corrente = "202627"
  # (senza, e' nil e Miur::Adozione.per_anno(nil) torna vuoto: il vecchio ponte
  # new_adozioni aveva un COALESCE su max(miur_adozioni), ora rimosso by design).
  fixtures :classi, :scuole, :accounts, "miur/scuole", "miur/adozioni", :libri, :editori, :categorie, :users

  test "tappa_target delegates to scuola" do
    classe = classi(:prima_a_fizzy)
    assert_equal classe.scuola, classe.tappa_target
  end

  test "default_titolo_tappa references the sezione" do
    classe = classi(:prima_a_fizzy)
    assert_match(/Classe/, classe.default_titolo_tappa)
  end

  test "attive esclude le archiviate e include le attive" do
    attiva = classi(:prima_a)
    da_archiviare = classi(:quinta_a)
    da_archiviare.update!(stato: "archiviata")
    assert_includes Classe.attive, attiva
    assert_not_includes Classe.attive, da_archiviare
  end

  test "new_adozioni trova le righe per origine" do
    classe = classi(:prima_a)
    isbn = classe.new_adozioni.pluck(:codiceisbn)
    assert_includes isbn, miur_adozioni(:prima_a_matematica).codiceisbn
  end

  test "costruisci_adozioni! crea snapshot taggati per anno" do
    classe = classi(:prima_a)
    assert_difference -> { classe.adozioni.where(anno_scolastico: "202627").count }, 1 do
      classe.costruisci_adozioni!(anno_scolastico: "202627")
    end
    ad = classe.adozioni.find_by(anno_scolastico: "202627")
    assert_equal classe.codice_ministeriale_origine, ad.codicescuola
    assert_equal miur_adozioni(:prima_a_matematica).codiceisbn, ad.codice_isbn
    assert_equal 1250, ad.prezzo_cents                    # fixture prezzo "12,50"
    assert ad.da_acquistare                               # fixture daacquist "Si"
    assert_not ad.nuova_adozione                          # fixture nuovaadoz "No"
    assert_equal libri(:matematica_facile_1).id, ad.libro_id  # link per codice_isbn, scopato per account
  end

  test "costruisci_adozioni! è idempotente" do
    classe = classi(:prima_a)
    classe.costruisci_adozioni!(anno_scolastico: "202627")
    assert_no_difference -> { Adozione.count } do
      classe.costruisci_adozioni!(anno_scolastico: "202627")
    end
  end
end
