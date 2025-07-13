# == Schema Information
#
# Table name: documenti
#
#  id               :integer          not null, primary key
#  numero_documento :integer
#  user_id          :integer          not null
#  data_documento   :date
#  causale_id       :integer
#  tipo_pagamento   :integer
#  consegnato_il    :date
#  status           :integer
#  iva_cents        :integer
#  totale_cents     :integer
#  spese_cents      :integer
#  totale_copie     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  clientable_id    :integer
#  clientable_type  :string
#  tipo_documento   :integer
#  note             :text
#  referente        :text
#  pagato_il        :datetime
#
# Indexes
#
#  index_documenti_on_causale_id                         (causale_id)
#  index_documenti_on_clientable_type_and_clientable_id  (clientable_type,clientable_id)
#  index_documenti_on_user_id                            (user_id)
#

class Documento < ApplicationRecord
  belongs_to :user
  belongs_to :clientable, polymorphic: true, optional: true
  belongs_to :causale

  has_many :documento_righe, -> { order(posizione: :asc) }, inverse_of: :documento, dependent: :destroy
  has_many :righe, through: :documento_righe

  accepts_nested_attributes_for :documento_righe # ,  :reject_if => lambda { |a| (a[:riga_id].nil?)}, :allow_destroy => false

  enum :status, { ordine: 0, in_consegna: 1, da_pagare: 2, da_registrare: 3, corrispettivi: 4, fattura: 5 }
  enum :tipo_pagamento,
       { contanti: 0, assegno: 1, bonifico: 2, bancomat: 3, carta_di_credito: 4, paypal: 5, satispay: 6, cedole: 7 }

  # enum tipo_movimento: { ordine: 0, vendita: 1, carico: 2 }
  # enum movimento: { entrata: 0, uscita: 1 }

  delegate :tipo_movimento, :movimento, to: :causale

  extend FilterableModel
  class << self
    def filter_proxy = Filters::DocumentoFilterProxy
  end

  attr_accessor :form_step

  with_options if: -> { required_for_step?(:tipo_documento) } do
    validates :causale_id, presence: true
    validates :numero_documento, presence: true
    validates :data_documento, presence: true
  end

  with_options if: -> { required_for_step?(:cliente) } do
    validates :clientable_type, presence: true
    validates :clientable_id, presence: true
  end

  with_options if: -> { required_for_step?(:dettaglio) } do
    # validates :documento_righe, length: {minimum: 1, message: 'deve esserci almeno una riga.'}
  end

  def self.form_steps
    {
      tipo_documento: %i[causale_id numero_documento data_documento clientable_type clientable_id],
      cliente: %i[clientable_type clientable_id referente note],
      dettaglio: [documento_righe_attributes:
                    [:id, :posizione,
                     { riga_attributes: %i[id libro_id quantita prezzo prezzo_cents prezzo_copertina_cents sconto iva_cents status _destroy] }]],
      stato_documento: %i[status tipo_pagamento consegnato_il pagato_il]
    }
  end

  def required_for_step?(step)
    # All fields are required if no form step is present
    return true if form_step.nil?

    # All fields from previous steps are required
    ordered_keys = self.class.form_steps.keys.map(&:to_sym)
    !!(ordered_keys.index(step) <= ordered_keys.index(form_step))
  end

  def clientable
    super || Domain::NessunCliente.new
  end

  def incompleto?
    causale.blank? || clientable.is_a?(Domain::NessunCliente)
  end

  def vendita?
    tipo_movimento == 'vendita' || (tipo_movimento == 'ordine' && status != 'ordine')
  end

  # poi
  def ordine_evaso?
    tipo_movimento == 'ordine' && status != 'ordine'
  end

  def ordine_in_corso?
    tipo_movimento == 'ordine' && status == 'ordine'
  end

  def registrato?
    %w[TD01 TD04 TD24].include?(causale.causale)
  end

  def pagato?
    pagato_il.present?
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
