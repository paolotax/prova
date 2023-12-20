# == Schema Information
#
# Table name: view_documenti
#
#  id                   :text             primary key
#  fornitore            :string
#  iva_fornitore        :string
#  cliente              :string
#  iva_cliente          :string
#  tipo_documento       :string
#  numero_documento     :string
#  data_documento       :date
#  quantita_totale      :bigint
#  importo_netto_totale :float
#  totale_documento     :float
#  conto                :text
#  check                :float
#
require "test_helper"

class Views::DocumentoTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
