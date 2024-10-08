# == Schema Information
#
# Table name: documenti
#
#  id               :bigint           not null, primary key
#  clientable_type  :string
#  consegnato_il    :date
#  data_documento   :date
#  iva_cents        :bigint
#  note             :text
#  numero_documento :integer
#  pagato_il        :datetime
#  referente        :text
#  spese_cents      :bigint
#  status           :integer
#  tipo_documento   :integer
#  tipo_pagamento   :integer
#  totale_cents     :bigint
#  totale_copie     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  causale_id       :bigint           not null
#  clientable_id    :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_documenti_on_causale_id                         (causale_id)
#  index_documenti_on_clientable_type_and_clientable_id  (clientable_type,clientable_id)
#  index_documenti_on_user_id                            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (user_id => users.id)
#
class Documento < ApplicationRecord
  
  belongs_to :user
  belongs_to :clientable, polymorphic: true
  belongs_to :causale

  has_many :documento_righe, -> { order(posizione: :asc) }, inverse_of: :documento, dependent: :destroy
  has_many :righe, through: :documento_righe

  accepts_nested_attributes_for :documento_righe #,  :reject_if => lambda { |a| (a[:riga_id].nil?)}, :allow_destroy => false

  validates :numero_documento, presence: true
  validates :data_documento, presence: true

  enum :status, [:ordine, :in_consegna, :da_pagare, :da_registrare, :corrispettivi, :fattura]
  enum :tipo_pagamento, [:contanti, :assegno, :bonifico, :bancomat, :carta_di_credito, :paypal, :satispay, :cedole]
  
  #enum tipo_movimento: { ordine: 0, vendita: 1, carico: 2 }   
  #enum movimento: { entrata: 0, uscita: 1 }
  
  delegate :tipo_movimento, :movimento, to: :causale

  extend FilterableModel
  class << self
    def filter_proxy = Filters::DocumentoFilterProxy
  end

  def vendita?
    tipo_movimento == "vendita" || ( tipo_movimento == "ordine" && status != "ordine" )
  end
  # poi
  def ordine_evaso?
    tipo_movimento == "ordine" && status != "ordine"
  end

  def ordine_in_corso?
    tipo_movimento == "ordine" && status == "ordine"
  end

  def totale_importo
    righe.sum(&:importo)
  end

  def totale_copie
    righe.sum(&:quantita)
  end



  def self.clear_all
    Documento.destroy_all
    Riga.destroy_all
    Documento.all 
    Riga.all 
  end

  def self.reset_righe
    Documento.all.each do |documento|
      documento.documento_righe.order(:created_at).each.with_index(1) do |documento_riga, index|
        documento_riga.update_column :posizione, index
      end
    end
  end

  
end
