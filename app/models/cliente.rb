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
#  user_id                 :bigint
#
# Indexes
#
#  index_clienti_on_user_id  (user_id)
#
class Cliente < ApplicationRecord

  #validates :partita_iva, presence: true, uniqueness: true

  has_many :documenti

  def self.assign_from_row(row)
    if row[:partita_iva].nil?
      cliente = Current.user.clienti.where(codice_fiscale: row[:codice_fiscale]).first_or_initialize      
    else
      cliente = Current.user.clienti.where(partita_iva: row[:partita_iva]).first_or_initialize
    end
    cliente.assign_attributes row.to_hash
    cliente
  end

  def to_s
    "#{denominazione} - #{comune}"
  end

  def to_combobox_display
    "#{denominazione} - #{comune}"
  end

  
end
