# == Schema Information
#
# Table name: clienti
#
#  id                      :uuid             not null, primary key
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
#  geocoded                :boolean
#  id_paese                :string
#  indirizzo               :string
#  indirizzo_telematico    :string
#  latitude                :float
#  longitude               :float
#  metodo_di_pagamento     :string
#  nazione                 :string
#  nome                    :string
#  numero_civico           :string
#  partita_iva             :string
#  pec                     :string
#  provincia               :string
#  slug                    :string
#  telefono                :string
#  tipo_cliente            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :uuid             not null
#  user_id                 :bigint
#
# Indexes
#
#  index_clienti_on_account_id                 (account_id)
#  index_clienti_on_account_id_and_created_at  (account_id,created_at)
#  index_clienti_on_slug                       (slug) UNIQUE
#  index_clienti_on_user_id                    (user_id)
#

class Cliente < ApplicationRecord
  include AccountScoped
  include Appuntabile
  include HasEntries
  include Navigable
  include Saldabile

  geocoded_by :address   # Assumi che il modello Cliente abbia un campo address
  after_validation :geocode, if: ->(obj) { (obj.indirizzo_changed? || obj.numero_civico_changed? ||obj.cap_changed? || obj.comune_changed? || obj.provincia_changed?) } 


  belongs_to :user
  has_many :documenti, -> { where("documenti.clientable_type = 'Cliente' and documenti.user_id = ?", Current.user.id) },
           as: :clientable, dependent: :destroy
  has_many :righe, through: :documenti

  has_many :tappe, -> { where("tappe.tappable_type = 'Cliente' and tappe.user_id = ?", Current.user.id) }, as: :tappable

  # Relazione con sconti
  has_many :sconti, as: :scontabile, dependent: :destroy 


  include MultistepFormModel
  
  include Searchable
  search_on :denominazione, :partita_iva, :indirizzo, :comune, :codice_fiscale, :cognome, :nome

  include PgSearch::Model

  pg_search_scope :search_all_word,
    against: [:denominazione, :partita_iva, :indirizzo, :comune, :codice_fiscale, :cognome, :nome],
    using: { tsearch: { any_word: false, prefix: true } }
  
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

  def geocoded?
    latitude.present? && longitude.present?
  end

  def indirizzo_navigator
    [indirizzo, numero_civico, cap, comune, provincia].compact_blank.join(" ")
  end

  def previous
    Current.user.clienti.where("denominazione < ?", denominazione).order(denominazione: :desc).first
  end

  def next
    Current.user.clienti.where("denominazione > ?", denominazione).order(denominazione: :asc).first
  end

  def importo_entrate
    righe.joins(documenti: :causale).where("causali.movimento = ? AND documenti.documento_padre_id IS NULL", 1).sum(&:importo).to_f 
  end

  def importo_uscite
    righe.joins(documenti: :causale).where("causali.movimento = ? AND documenti.documento_padre_id IS NULL", 0).sum(&:importo).to_f
  end

  def to_combobox_display
    "#{denominazione} - #{comune}"
  end

  attr_accessor :cliente_id
  
  def cliente_id=(cliente_id)
    self.clientable_id = cliente_id
    self.clientable_type = 'Cliente'
  end

  private

  def entry_appunto_ids
    appunti.published.pluck(:id).map(&:to_s)
  end

  def entry_documento_ids
    documenti.where(documento_padre_id: nil).pluck(:id).map(&:to_s)
  end
end
