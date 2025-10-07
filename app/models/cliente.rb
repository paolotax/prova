# == Schema Information
#
# Table name: clienti
#
#  id                      :integer          not null, primary key
#  codice_cliente          :string
#  tipo_cliente            :string
#  indirizzo_telematico    :string
#  email                   :string
#  pec                     :string
#  telefono                :string
#  id_paese                :string
#  partita_iva             :string
#  codice_fiscale          :string
#  denominazione           :string
#  nome                    :string
#  cognome                 :string
#  codice_eori             :string
#  nazione                 :string
#  cap                     :string
#  provincia               :string
#  comune                  :string
#  indirizzo               :string
#  numero_civico           :string
#  beneficiario            :string
#  condizioni_di_pagamento :string
#  metodo_di_pagamento     :string
#  banca                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :integer
#  slug                    :string
#  latitude                :float
#  longitude               :float
#  geocoded                :boolean
#
# Indexes
#
#  index_clienti_on_slug     (slug) UNIQUE
#  index_clienti_on_user_id  (user_id)
#

class Cliente < ApplicationRecord

  geocoded_by :address   # Assumi che il modello Cliente abbia un campo address
  after_validation :geocode, if: ->(obj) { (obj.indirizzo_changed? || obj.numero_civico_changed? ||obj.cap_changed? || obj.comune_changed? || obj.provincia_changed?) } 


  belongs_to :user
  has_many :documenti, -> { where("documenti.clientable_type = 'Cliente' and documenti.user_id = ?", Current.user.id) },
           as: :clientable, dependent: :destroy
  has_many :righe, through: :documenti

  has_many :tappe, -> { where("tappe.tappable_type = 'Cliente' and tappe.user_id = ?", Current.user.id) }, as: :tappable

  # Relazione con sconti
  has_many :sconti, as: :scontabile, dependent: :destroy 

  extend FilterableModel
  class << self
    def filter_proxy = Filters::ClienteFilterProxy
  end

  include MultistepFormModel
  include Searchable
  search_on :denominazione, :partita_iva, :indirizzo, :comune, :codice_fiscale, :cognome, :nome

  #validates :partita_iva, presence: true, numericality: true, length: { is: 11 }, uniqueness: { scope: :user_id }
  validates :denominazione, presence: true

  #validates :condizioni_di_pagamento, presence: true
 
  def direzione_or_privata
    "cliente".html_safe
  end

  def to_s
    "#{denominazione} - #{comune}"
  end

  def can_delete?
    documenti.empty?
  end

  attr_accessor :address
  def address
    "#{self.indirizzo} #{self.numero_civico} \n #{self.cap} #{self.comune} #{self.provincia}".strip
  end

  def previous
    Current.user.clienti.where("denominazione < ?", denominazione).order(denominazione: :desc).first
  end

  def next
    Current.user.clienti.where("denominazione > ?", denominazione).order(denominazione: :asc).first
  end

  def importo_entrate
    righe.joins(documenti: :causale).where("causali.movimento = ?", 1).sum(&:importo).to_f 
  end

  def importo_uscite
    righe.joins(documenti: :causale).where("causali.movimento = ?", 0).sum(&:importo).to_f
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
