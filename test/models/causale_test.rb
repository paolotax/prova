# == Schema Information
#
# Table name: causali
#
#  id                 :bigint           not null, primary key
#  causale            :string
#  causali_successive :json
#  clientable_types   :json             not null
#  gestione_consegna  :boolean          default(TRUE), not null
#  gestione_pagamento :boolean          default(TRUE), not null
#  magazzino          :string
#  mostra_importo     :boolean          default(TRUE), not null
#  movimento          :integer
#  priorita           :integer          default(0)
#  stati_successivi   :json
#  stato_iniziale     :string
#  tipo_movimento     :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_causali_on_priorita        (priorita)
#  index_causali_on_stato_iniziale  (stato_iniziale)
#
require "test_helper"

class CausaleTest < ActiveSupport::TestCase
  fixtures :causali

  test "segno: entrata carica, uscita scarica" do
    assert_equal 1, causali(:ordine).segno          # movimento entrata
    assert_equal 1, causali(:nota_credito).segno    # TD04, entrata
    assert_equal(-1, causali(:vendita).segno)       # movimento uscita
    assert_equal(-1, causali(:fattura).segno)       # TD01, uscita
  end

  test "SEGNO_SQL coincide con #segno per ogni causale" do
    rows = Causale.pluck(:id, Arel.sql(Causale::SEGNO_SQL)).to_h
    Causale.find_each do |causale|
      assert_equal causale.segno, rows[causale.id], "segno divergente per #{causale.causale}"
    end
  end

  test "predicati magazzino" do
    assert causali(:fattura).magazzino_vendita?
    assert_not causali(:fattura).magazzino_campionario?
    assert causali(:scarico_saggi).magazzino_campionario?
    assert causali(:mancante).magazzino_campionario?
  end
end
