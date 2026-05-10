# == Schema Information
#
# Table name: bolla_visione_righe
#
#  id                :uuid             not null, primary key
#  classi_target     :string
#  consegna          :jsonb
#  esito             :integer
#  position          :integer
#  processato_at     :datetime
#  quantita          :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  bolla_visione_id  :uuid             not null
#  documento_riga_id :bigint
#  libro_id          :bigint           not null
#
# Indexes
#
#  index_bolla_visione_righe_on_account_id                  (account_id)
#  index_bolla_visione_righe_on_bolla_visione_id            (bolla_visione_id)
#  index_bolla_visione_righe_on_bolla_visione_id_and_esito  (bolla_visione_id,esito)
#  index_bolla_visione_righe_on_documento_riga_id           (documento_riga_id)
#  index_bolla_visione_righe_on_libro_id                    (libro_id)
#  index_bolla_visione_righe_on_processato_at               (processato_at)
#
require "test_helper"

class BollaVisioneRigaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :scuole, :collane, :bolle_visione, :bolla_visione_righe, :confezione_righe

  test "scope aperte ritorna righe senza processato_at" do
    riga = bolla_visione_righe(:aperta)
    assert_includes BollaVisioneRiga.aperte, riga
    assert_not_includes BollaVisioneRiga.chiuse, riga
  end

  test "scope chiuse ritorna righe con processato_at" do
    riga = bolla_visione_righe(:chiusa_in_saggio)
    assert_includes BollaVisioneRiga.chiuse, riga
    assert_not_includes BollaVisioneRiga.aperte, riga
  end

  test "esito enum mappa i 5 valori attesi" do
    assert_equal({ "in_saggio" => 0, "venduto_fattura" => 1, "venduto_corrispettivi" => 2,
                   "mancante" => 3, "rientrato" => 4 }, BollaVisioneRiga.esiti)
  end

  test "splitta_in_fascicoli! genera N righe-fascicolo mancanti e chiude la confezione" do
    riga = bolla_visione_righe(:aperta_confezione)
    fascicoli = riga.libro.fascicoli.first(2)
    assert_equal 2, fascicoli.size

    nuove = nil
    assert_difference -> { BollaVisioneRiga.count } => 2 do
      nuove = riga.splitta_in_fascicoli!(fascicoli, esito_confezione: :rientrato)
    end

    assert_equal 2, nuove.size
    assert_equal fascicoli.map(&:id).sort, nuove.map(&:libro_id).sort
    assert nuove.all?(&:mancante?)
    assert nuove.all? { |r| r.processato_at.present? }

    riga.reload
    assert_equal "rientrato", riga.esito
    assert_not_nil riga.processato_at
  end

  test "splitta! divide riga quantita N in N righe quantita 1" do
    riga = bolla_visione_righe(:aperta_due)
    assert_equal 2, riga.quantita

    assert_difference -> { BollaVisioneRiga.count } => 1 do
      riga.splitta!
    end
    assert_raises(ActiveRecord::RecordNotFound) { riga.reload }

    nuove = BollaVisioneRiga.where(libro_id: riga.libro_id, bolla_visione_id: riga.bolla_visione_id, quantita: 1)
    assert nuove.count >= 2
  end
end
