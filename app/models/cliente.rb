# == Schema Information
#
# Table name: clienti
#
#  id                      :bigint           not null, primary key
#  banca                   :string
#  beneficiario            :string
#  cap                     :string
#  codice_cliente          :string
#  codice_eori             :string
#  codice_fiscale          :string
#  cognome                 :string
#  comune                  :string
#  condizioni_di_pagamento :string
#  denominazione           :string
#  email                   :string
#  id_paese                :string
#  indirizzo               :string
#  indirizzo_telematico    :string
#  metodo_di_pagamento     :string
#  nazione                 :string
#  nome                    :string
#  numero_civico           :string
#  partita_iva             :string
#  pec                     :string
#  provincia               :string
#  telefono                :string
#  tipo_cliente            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class Cliente < ApplicationRecord

  #validates :partita_iva, presence: true, uniqueness: true

  def self.assign_from_row(row)
    if row[:partita_iva].blank?
      cliente = Cliente.where(codice_fiscale: row[:codice_fiscale]).first_or_initialize
      
    else
      cliente = Cliente.where(partita_iva: row[:partita_iva]).first_or_initialize
    end
    cliente.assign_attributes row.to_hash
    cliente
  end

  
end