# == Schema Information
#
# Table name: miur_adozioni
#
#  id               :bigint           not null, primary key
#  anno_scolastico  :string           not null, primary key
#  annocorso        :string
#  autori           :string
#  codiceisbn       :string
#  codicescuola     :string
#  combinazione     :string
#  consigliato      :string
#  daacquist        :string
#  disciplina       :string
#  editore          :string
#  nuovaadoz        :string
#  prezzo           :string
#  sezioneanno      :string
#  sottotitolo      :string
#  tipogradoscuola  :string
#  titolo           :string
#  volume           :string
#  import_scuola_id :bigint
#
# Indexes
#
#  idx_miur_adoz_ee                (codicescuola) WHERE ((tipogradoscuola)::text = 'EE'::text)
#  idx_miur_adozioni_codicescuola  (codicescuola)
#  idx_miur_adozioni_disc_anno_tg  (disciplina,annocorso,tipogradoscuola)
#  index_miur_adozioni_on_classe   (anno_scolastico,codicescuola,annocorso,sezioneanno,combinazione,codiceisbn,disciplina) UNIQUE
#
require "test_helper"

class Miur::AdozioneTest < ActiveSupport::TestCase
  fixtures "miur/adozioni", "miur/scuole"

  test "per_anno filtra sulla partizione" do
    assert Miur::Adozione.per_anno("202627").any?
    assert Miur::Adozione.per_anno("202627").all? { |a| a.anno_scolastico == "202627" }
  end

  test "anno_corrente deriva dal massimo di miur_scuole" do
    assert_equal Miur::Scuola.maximum(:anno_scolastico), Miur.anno_corrente
    assert_equal "202627", Miur.anno_corrente
  end

  test "escluso_dal_tetto? per alternativa e parascolastica" do
    assert Miur::Adozione.new(disciplina: "ADOZIONE ALTERNATIVA ALLA RELIGIONE C.").escluso_dal_tetto?
    refute Miur::Adozione.new(disciplina: "ITALIANO").escluso_dal_tetto?
  end

  test "prezzo_euro converte la stringa MIUR" do
    assert_equal BigDecimal("12.34"), Miur::Adozione.new(prezzo: "12,34").prezzo_euro
    assert_nil Miur::Adozione.new(prezzo: "ND").prezzo_euro
  end

  test "lookup per id richiede anche l'anno (PK composita)" do
    assert_equal ["anno_scolastico", "id"], Miur::Adozione.primary_key
  end
end
