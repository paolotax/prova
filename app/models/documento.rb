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

  before_save :imposta_stato_iniziale_da_causale, if: :causale_id_changed?
  before_save :ricalcola_totali_se_necessario
  after_update :propaga_stato_ai_figli, if: :saved_change_to_status?
  after_destroy :riporta_documenti_orfani_a_stato_precedente

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

  scope :solo_padri, -> { where(documento_padre_id: nil) }

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

  # Restituisce tutti i discendenti (figli, nipoti, pronipoti, ecc.) in un array piatto
  def tutti_i_discendenti
    documenti_derivati.flat_map { |figlio| [figlio] + figlio.tutti_i_discendenti }
  end

  # Restituisce la struttura ad albero dei discendenti
  # Formato: [{ documento: Documento, figli: [...] }, ...]
  def albero_discendenti
    documenti_derivati.map do |figlio|
      { documento: figlio, figli: figlio.albero_discendenti }
    end
  end

  # Trova lo stato precedente nella gerarchia degli stati_successivi della propria causale
  def trova_stato_precedente_nella_causale
    Rails.logger.debug "    trova_stato_precedente_nella_causale per: #{causale&.causale}"
    Rails.logger.debug "      status corrente: #{status}"
    Rails.logger.debug "      stati_successivi: #{causale&.stati_successivi.inspect}"

    return nil unless status.present?
    return nil unless causale&.stati_successivi.present?

    # stati_successivi è un JSON array di stati in ordine per questa causale
    stati = causale.stati_successivi
    return nil unless stati.is_a?(Array) && stati.any?

    Rails.logger.debug "      array stati: #{stati.inspect}"

    # Trova l'indice dello stato corrente del documento
    indice_corrente = stati.index(status.to_s)
    Rails.logger.debug "      indice_corrente: #{indice_corrente.inspect}"

    return nil unless indice_corrente && indice_corrente > 0

    # Ritorna lo stato precedente nell'array
    stato_prec = stati[indice_corrente - 1]
    Rails.logger.debug "      stato precedente: #{stato_prec}"
    stato_prec
  end

  private

  # Imposta lo stato iniziale dalla causale quando viene creato un documento
  def imposta_stato_iniziale_da_causale
    return if status.present? # Non sovrascrivere se già impostato
    return unless causale&.stato_iniziale.present?

    # Verifica che lo stato_iniziale sia valido per l'enum status
    if Documento.statuses.key?(causale.stato_iniziale)
      self.status = causale.stato_iniziale
    end
  end

  # Ricalcola i totali se ci sono righe ma i totali non sono impostati
  def ricalcola_totali_se_necessario
    return if documento_righe.empty?
    return if totale_cents.present? && totale_cents > 0

    totale_importo_calcolato = righe.sum(&:importo_cents)
    totale_copie_calcolato = righe.sum(&:quantita)

    self.totale_cents = totale_importo_calcolato
    self.totale_copie = totale_copie_calcolato
  end

  # Propaga lo stato a tutti i documenti figli quando viene modificato
  def propaga_stato_ai_figli
    tutti_i_discendenti.each do |discendente|
      discendente.update_column(:status, status)
    end
  end

  # Riporta tutti i documenti collegati dello stesso cliente allo stato precedente
  def riporta_documenti_orfani_a_stato_precedente
    return unless clientable_id && clientable_type

    Rails.logger.debug "=== RIPORTA DOCUMENTI A STATO PRECEDENTE ==="
    Rails.logger.debug "Documento eliminato: #{id} - #{causale&.causale} - status: #{status} - priorità: #{causale&.priorita}"

    # Lo stato target è lo stato precedente del documento ELIMINATO
    stato_target = trova_stato_precedente_nella_causale

    unless stato_target
      Rails.logger.debug "  Nessuno stato precedente trovato per il documento eliminato"
      return
    end

    Rails.logger.debug "  Stato target da applicare: #{stato_target}"

    # Trova TUTTI i documenti dello stesso cliente
    tutti_documenti = Documento.where(
      clientable_id: clientable_id,
      clientable_type: clientable_type
    )

    Rails.logger.debug "  Documenti totali del cliente: #{tutti_documenti.count}"

    # Aggiorna tutti i documenti con lo stato precedente
    tutti_documenti.each do |doc|
      Rails.logger.debug "    Aggiorno: #{doc.id} - #{doc.causale&.causale} da #{doc.status} a #{stato_target}"
      doc.update_column(:status, Documento.statuses[stato_target])
    end
  end
end
