# == Schema Information
#
# Table name: view_righe
#
#  id               :bigint
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
#  conto            :text
#
class Views::Riga < ApplicationRecord

    def documento 
        
        Views::Documento.where(
            numero_documento: self.numero_documento, 
            data_documento: self.data_documento, 
            fornitore: self.fornitore 
        ).first
      
    end

end
