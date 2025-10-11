# == Schema Information
#
# Table name: imports
#
#  id               :bigint           not null, primary key
#  cliente          :string
#  codice_articolo  :string
#  data_documento   :date
#  descrizione      :string
#  fornitore        :string
#  importo_netto    :float
#  iva              :integer
#  iva_cliente      :string
#  iva_fornitore    :string
#  numero_documento :string
#  prezzo_unitario  :float
#  quantita         :integer
#  riga             :integer
#  sconto           :float
#  tipo_documento   :string
#  totale_documento :float
#

require "test_helper"

class ImportTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
