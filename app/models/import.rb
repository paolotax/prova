# == Schema Information
#
# Table name: imports
#
#  id               :integer          not null, primary key
#  fornitore        :string
#  iva_fornitore    :string
#  cliente          :string
#  iva_cliente      :string
#  tipo_documento   :string
#  numero_documento :string
#  data_documento   :date
#  totale_documento :float
#  riga             :integer
#  codice_articolo  :string
#  descrizione      :string
#  prezzo_unitario  :float
#  quantita         :integer
#  importo_netto    :float
#  sconto           :float
#  iva              :integer
#

class Import < ApplicationRecord
end
