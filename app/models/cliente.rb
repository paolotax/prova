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

  belongs_to :user  
  has_many :documenti, -> { where("documenti.clientable_type = 'Cliente' and documenti.user_id = ?", Current.user.id) }, as: :clientable 
  has_many :righe, through: :documenti
  
  extend FilterableModel
  class << self
    def filter_proxy = Filters::ClienteFilterProxy
  end

  include MultistepFormModel
  include Searchable
  search_on :denominazione, :partita_iva, :indirizzo, :comune, :codice_fiscale, :cognome, :nome

  #validates :partita_iva, presence: true, numericality: true, length: { is: 11 }, uniqueness: { scope: :user_id }
  validates :denominazione, presence: true

  validates :condizioni_di_pagamento, presence: true
 
  def to_s
    "#{denominazione} - #{comune}"
  end

  def to_combobox_display
    "#{denominazione} - #{comune}"
  end

  attr_accessor :cliente_id
  
  def cliente_id=(cliente_id)
    self.clientable_id = cliente_id
    self.clientable_type = 'Cliente'
  end 
end
