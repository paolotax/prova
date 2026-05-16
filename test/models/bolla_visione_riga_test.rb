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

  test "esplodi_in_fascicoli! sostituisce la confezione con N righe fascicolo che ereditano lo stato" do
    riga = bolla_visione_righe(:aperta_confezione)
    fascicoli_ids = riga.libro.fascicoli.pluck(:id)
    bolla = riga.bolla_visione

    assert_difference -> { BollaVisioneRiga.count } => fascicoli_ids.size - 1 do
      riga.esplodi_in_fascicoli!
    end
    assert_raises(ActiveRecord::RecordNotFound) { riga.reload }

    nuove = bolla.bolla_visione_righe.where(libro_id: fascicoli_ids)
    assert_equal fascicoli_ids.size, nuove.count
    assert nuove.all? { |r| r.quantita == 1 }
    assert nuove.all? { |r| r.esito.nil? && r.processato_at.nil? }
  end

  test "esplodi_in_fascicoli! eredita esito e processato_at quando la riga e' chiusa" do
    riga = bolla_visione_righe(:aperta_confezione)
    riga.update!(esito: :rientrato, processato_at: 1.hour.ago)
    fascicoli_ids = riga.libro.fascicoli.pluck(:id)
    bolla = riga.bolla_visione

    riga.esplodi_in_fascicoli!

    nuove = bolla.bolla_visione_righe.where(libro_id: fascicoli_ids)
    assert nuove.all?(&:rientrato?)
    assert nuove.all? { |r| r.processato_at.present? }
  end

  test "esplodi_in_fascicoli! moltiplica le righe per la quantita della confezione" do
    riga = bolla_visione_righe(:aperta_confezione)
    riga.update!(quantita: 2)
    fascicoli_count = riga.libro.fascicoli.size
    bolla = riga.bolla_visione

    assert_difference -> { BollaVisioneRiga.count } => (fascicoli_count * 2) - 1 do
      riga.esplodi_in_fascicoli!
    end

    riga.libro.fascicoli.each do |f|
      assert_equal 2, bolla.bolla_visione_righe.where(libro_id: f.id).count
    end
  end

  test "esplodi_in_fascicoli! e' no-op su libro senza fascicoli" do
    riga = bolla_visione_righe(:aperta)
    assert riga.libro.fascicoli.empty?

    assert_no_difference -> { BollaVisioneRiga.count } do
      assert_equal riga, riga.esplodi_in_fascicoli!
    end
    assert_nothing_raised { riga.reload }
  end
end
