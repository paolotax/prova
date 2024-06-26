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

  def self.import(file)
    CSV.foreach(file.path, headers: true) do |row|
      raise row.inspect
      Cliente.create! row.to_hash
    end
  end

  def self.search_any_word(search)
    where("cliente ILIKE :search", search: "%#{search}%")
  end

  def self.search(search)
    if search
      where("cliente ILIKE :search", search: "%#{search}%")
    else
      all
    end
  end

end
