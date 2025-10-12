# == Schema Information
#
# Table name: documenti
#
#  id                     :bigint           not null, primary key
#  clientable_type        :string
#  consegnato_il          :date
#  data_documento         :date
#  iva_cents              :bigint
#  note                   :text
#  numero_documento       :integer
#  pagato_il              :datetime
#  referente              :text
#  spese_cents            :bigint
#  status                 :integer
#  tipo_documento         :integer
#  tipo_pagamento         :integer
#  totale_cents           :bigint
#  totale_copie           :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  causale_id             :bigint
#  clientable_id          :bigint
#  derivato_da_causale_id :integer
#  documento_padre_id     :integer
#  user_id                :bigint           not null
#
# Indexes
#
#  index_documenti_on_causale_id                         (causale_id)
#  index_documenti_on_clientable_type_and_clientable_id  (clientable_type,clientable_id)
#  index_documenti_on_derivato_da_causale_id             (derivato_da_causale_id)
#  index_documenti_on_documento_padre_id                 (documento_padre_id)
#  index_documenti_on_user_id                            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (derivato_da_causale_id => causali.id)
#  fk_rails_...  (documento_padre_id => documenti.id)
#  fk_rails_...  (user_id => users.id)
#

class Documento < ApplicationRecord
  belongs_to :user
  belongs_to :clientable, polymorphic: true, optional: true
  belongs_to :causale, optional: true
  belongs_to :documento_padre, class_name: 'Documento', optional: true
  belongs_to :derivato_da_causale, class_name: 'Causale', optional: true

  has_many :documento_righe, -> { order(posizione: :asc) }, inverse_of: :documento, dependent: :destroy
  has_many :righe, through: :documento_righe
  has_many :documenti_derivati, class_name: 'Documento', foreign_key: :documento_padre_id, dependent: :nullify

  accepts_nested_attributes_for :documento_righe # ,  :reject_if => lambda { |a| (a[:riga_id].nil?)}, :allow_destroy => false

  enum :status, { ordine: 0, in_consegna: 1, da_pagare: 2, da_registrare: 3, corrispettivi: 4, fattura: 5, bozza: 6 }
  enum :tipo_pagamento,
       { contanti: 0, assegno: 1, bonifico: 2, bancomat: 3, carta_di_credito: 4, paypal: 5, satispay: 6, cedole: 7 }

  # enum tipo_movimento: { ordine: 0, vendita: 1, carico: 2 }
  # enum movimento: { entrata: 0, uscita: 1 }

  delegate :tipo_movimento, :movimento, to: :causale, allow_nil: true

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
    # Bozza documents don't require validation
    return false if status == 'bozza'

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
    return totale_cents / 100.0 if totale_cents.present?
    righe.sum(&:importo)
  end

  def totale_copie
    return super if super.present?
    righe.sum(&:quantita)
  end

  def ricalcola_totali!
    totale_importo_calcolato = righe.sum(&:importo_cents)
    totale_copie_calcolato = righe.sum(&:quantita)

    update_columns(
      totale_cents: totale_importo_calcolato,
      totale_copie: totale_copie_calcolato
    )
  end



  def self.reset_righe
    Documento.all.each do |documento|
      documento.documento_righe.order(:created_at).each.with_index(1) do |documento_riga, index|
        documento_riga.update_column :posizione, index
      end
    end
  end

  # Workflow methods
  def puo_generare_da_causale?(causale_target)
    return false unless causale
    causale.causali_successive.include?(causale_target.id) || causale.causali_successive.include?(causale_target.causale)
  end

  def genera_documento_derivato(causale_nuova, attributes = {})
    nuovo = self.class.new(
      documento_padre: self,
      derivato_da_causale: self.causale,
      causale: causale_nuova,
      clientable: clientable,
      user: user,
      data_documento: Date.today,
      status: causale_nuova.stato_iniziale || 'bozza'
    )

    nuovo.assign_attributes(attributes)

    # Copia le righe del documento padre
    documento_righe.each do |doc_riga|
      nuovo.documento_righe.build(
        riga: doc_riga.riga.dup,
        posizione: doc_riga.posizione
      )
    end

    nuovo
  end

  def catena_documenti
    documenti = []
    documento_corrente = self

    # Risali alla radice
    while documento_corrente.documento_padre
      documento_corrente = documento_corrente.documento_padre
    end

    # Scendi fino all'ultimo derivato
    documenti << documento_corrente
    while documento_corrente.documenti_derivati.any?
      documento_corrente = documento_corrente.documenti_derivati.order(:created_at).last
      documenti << documento_corrente
    end

    documenti
  end

  def documento_radice
    documento_corrente = self
    documento_corrente = documento_corrente.documento_padre while documento_corrente.documento_padre
    documento_corrente
  end
end
