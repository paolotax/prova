# == Schema Information
#
# Table name: documenti
#
#  id                     :uuid             not null, primary key
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
#  account_id             :uuid             not null
#  causale_id             :bigint
#  clientable_id          :uuid
#  derivato_da_causale_id :integer
#  documento_padre_id     :uuid
#  user_id                :bigint           not null
#
# Indexes
#
#  index_documenti_on_account_id                 (account_id)
#  index_documenti_on_account_id_and_created_at  (account_id,created_at)
#  index_documenti_on_causale_id                 (causale_id)
#  index_documenti_on_clientable                 (clientable_type,clientable_id)
#  index_documenti_on_derivato_da_causale_id     (derivato_da_causale_id)
#  index_documenti_on_documento_padre_id         (documento_padre_id)
#  index_documenti_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (derivato_da_causale_id => causali.id)
#  fk_rails_...  (documento_padre_id => documenti.id)
#  fk_rails_...  (user_id => users.id)
#

class Documento < ApplicationRecord
  include AccountScoped
  include Entryable
  include Pagabile
  include Consegnabile
  # Closeable rimosso: ora usa Entry::Closeable via Entryable delegation

  belongs_to :user
  belongs_to :clientable, polymorphic: true, optional: true
  belongs_to :causale, optional: true
  belongs_to :documento_padre, class_name: 'Documento', optional: true
  belongs_to :derivato_da_causale, class_name: 'Causale', optional: true

  has_many :documento_righe, -> { order(posizione: :asc) }, inverse_of: :documento, dependent: :destroy
  has_many :righe, through: :documento_righe
  
  has_many :documenti_derivati, class_name: 'Documento', foreign_key: :documento_padre_id, dependent: :nullify

  accepts_nested_attributes_for :documento_righe,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs[:riga_attributes].blank? && attrs[:riga_id].blank? }

  before_save :imposta_stato_iniziale_da_causale, if: :causale_id_changed?
  before_save :ricalcola_totali_se_necessario
  after_update :propaga_stato_ai_figli, if: :saved_change_to_status?
  after_destroy :riporta_documenti_orfani_a_stato_precedente
  before_destroy :riapri_documenti_figli

  # Callback per concern: propaga pagamento ai figli e auto-close
  after_save :propaga_pagamento_ai_figli, if: :just_marked_pagato?
  after_save :auto_close_se_completo
  # Rimosso: la chiusura del documento origine viene gestita nel controller
  # after_create :close_if_has_padre

  enum :status, { ordine: 0, in_consegna: 1, da_pagare: 2, da_registrare: 3, corrispettivi: 4, fattura: 5, bozza: 6 }

  # tipo_pagamento ora è sul modello Pagamento (concern Pagabile)
  # enum tipo_movimento: { ordine: 0, vendita: 1, carico: 2 }
  # enum movimento: { entrata: 0, uscita: 1 }

  delegate :tipo_movimento, :movimento, to: :causale, allow_nil: true

  attr_accessor :form_step

  # Virtual attribute per combobox multi-entità (stesso pattern di Appunto)
  # Formato: "Scuola:uuid" o "Cliente:id"
  def clientable_value
    return nil unless clientable.present? && !clientable.is_a?(Domain::NessunCliente)

    clientable.to_appuntabile_value
  end

  def clientable_value=(value)
    return if value.blank?

    klass, id = Appuntabile.parse_appuntabile_value(value)
    if klass && id
      begin
        self.clientable = klass.find_by(id: id)
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.warn "Invalid clientable_value format: #{value} - #{e.message}"
        nil
      end
    end
  end

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

  # Goldness-first ordering: SQL fragment for ORDER BY
  # Golden items (NOT EXISTS = false) sort before non-golden (true)
  GOLDEN_SORT_SQL = <<~SQL.squish
    (NOT EXISTS (
      SELECT 1 FROM entries e
      JOIN goldnesses g ON g.entry_id = e.id
      WHERE e.entryable_type = 'Documento' AND e.entryable_id = documenti.id::text
    ))
  SQL

  # No-op scope - golden ordering is applied in filter's ORDER BY
  scope :with_golden_first, -> { all }

  def self.form_steps
    {
      tipo_documento: %i[causale_id numero_documento data_documento clientable_type clientable_id],
      cliente: %i[clientable_type clientable_id referente note],
      dettaglio: [documento_righe_attributes:
                    [:id, :posizione,
                     { riga_attributes: %i[id libro_id quantita prezzo prezzo_cents prezzo_copertina_cents sconto iva_cents status _destroy] }]],
      stato_documento: %i[status]
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

  # I metodi pagato?, pagato_il, consegnato?, consegnato_il, tipo_pagamento
  # sono ora forniti dai concern Pagabile e Consegnabile

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
      # Il nuovo documento NON ha padre (è il documento principale)
      derivato_da_causale: self.causale,
      causale: causale_nuova,
      clientable: clientable,
      user: user,
      data_documento: Date.today,
      status: causale_nuova.stato_iniziale || 'bozza'
    )

    nuovo.assign_attributes(attributes)

    # Copia le righe del documento origine
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

  # Documenti esistenti a cui posso aggiungere le righe
  # (causale successiva valida, stesso cliente, non chiusi)
  def documenti_derivabili_esistenti
    return Documento.none unless causale&.causali_successive_records&.any?

    Documento.where(causale: causale.causali_successive_records)
      .where(clientable_type: clientable_type, clientable_id: clientable_id)
      .where(account_id: account_id)
      .where.not(id: id)
      .where.not(id: documento_padre_id) # Evita riferimenti circolari
      .order(data_documento: :desc)
      .limit(10)
  end

  # Label per il select nella dialog di derivazione
  def label_per_select
    "#{causale&.causale} #{numero_documento} del #{data_documento&.strftime('%d/%m/%Y')}"
  end

  # Aggiunge le righe di questo documento a uno esistente
  def aggiungi_righe_a(documento_target)
    transaction do
      documento_righe.each do |doc_riga|
        riga_duplicata = doc_riga.riga.dup
        riga_duplicata.save!
        documento_target.documento_righe.create!(riga: riga_duplicata)
      end

      # Imposta questo documento come figlio del target
      update!(documento_padre: documento_target)
    end
    documento_target
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

  # Propaga il pagamento a tutti i documenti figli
  def propaga_pagamento_ai_figli
    return unless pagamento.present?

    tutti_i_discendenti.each do |figlio|
      figlio.mark_pagato(
        user: pagamento.user,
        tipo_pagamento: pagamento.tipo_pagamento
      )
    end
  end

  # Auto-close quando il documento è sia pagato che consegnato
  def auto_close_se_completo
    close if pagato? && consegnato? && !closed?
  end

  # Chiude automaticamente documenti figli (es. DDT derivato da TD01)
  def close_if_has_padre
    return unless documento_padre_id.present?

    ensure_entry!
    close unless closed?
  end

  # Verifica se il documento è appena stato marcato come pagato
  def just_marked_pagato?
    pagamento.present? && pagamento.previously_new_record?
  end

  # Riapre i documenti figli quando il padre viene eliminato
  def riapri_documenti_figli
    documenti_derivati.each do |figlio|
      figlio.reopen if figlio.closed?
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
