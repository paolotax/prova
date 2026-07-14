# == Schema Information
#
# Table name: documenti
#
#  id                      :uuid             not null, primary key
#  clientable_type         :string
#  data_documento          :date
#  iva_cents               :bigint
#  note                    :text
#  numero_documento        :integer
#  referente               :text
#  spese_cents             :bigint
#  tipo_documento          :integer
#  tipo_pagamento_previsto :string
#  totale_cents            :bigint
#  totale_copie            :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :uuid             not null
#  causale_id              :bigint
#  clientable_id           :uuid
#  derivato_da_causale_id  :integer
#  documento_padre_id      :uuid
#  user_id                 :bigint           not null
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
  include Pianificabile

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

  before_save :ricalcola_totali_se_necessario
  after_create_commit :ricalcola_totali_dopo_creazione
  after_destroy_commit :ricalcola_saldo_clientable
  before_destroy :riapri_documenti_figli, prepend: true

  before_destroy :memorizza_libri_per_giacenza, prepend: true
  after_destroy :ricalcola_giacenze_libri_memorizzati
  after_update :ricalcola_giacenze_libri, if: -> { saved_change_to_causale_id? || saved_change_to_documento_padre_id? }

  # Rimosso: la chiusura del documento origine viene gestita nel controller
  # after_create :close_if_has_padre

  # tipo_pagamento ora è sul modello Pagamento (concern Pagabile)
  # status, consegnato_il, pagato_il, tipo_pagamento: colonne legacy rimosse (drop_legacy_magazzino)
  # La gestione stati è nei concern Consegnabile/Pagabile e negli scope attivi/completati

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

  # Residuo positivo: includono anche consegne/pagamenti parziali
  # (where.missing escluderebbe un documento al primo acconto o tranche)
  scope :da_consegnare, -> {
    where(causale_id: Causale.where(gestione_consegna: true))
      .where(<<~SQL.squish)
        (SELECT COALESCE(SUM(righe.quantita), 0)
           FROM documento_righe
           JOIN righe ON righe.id = documento_righe.riga_id
          WHERE documento_righe.documento_id = documenti.id)
        >
        (SELECT COALESCE(SUM(consegna_righe.quantita), 0)
           FROM consegne
           JOIN consegna_righe ON consegna_righe.consegna_id = consegne.id
          WHERE consegne.consegnabile_type = 'Documento'
            AND consegne.consegnabile_id = documenti.id)
      SQL
  }
  scope :da_pagare, -> {
    where(causale_id: Causale.where(gestione_pagamento: true))
      .where(<<~SQL.squish)
        COALESCE(documenti.totale_cents, 0)
        >
        (SELECT COALESCE(SUM(pagamenti.importo_cents), 0)
           FROM pagamenti
          WHERE pagamenti.pagabile_type = 'Documento'
            AND pagamenti.pagabile_id = documenti.id)
      SQL
  }

  # LEFT JOIN per ricerca su polymorphic clientable (Scuola, Cliente) + causale
  scope :left_joins_clientable, -> {
    joins(<<~SQL)
      LEFT JOIN scuole ON documenti.clientable_type = 'Scuola' AND documenti.clientable_id = scuole.id
      LEFT JOIN clienti ON documenti.clientable_type = 'Cliente' AND documenti.clientable_id = clienti.id
    SQL
  }

  scope :search_docs, ->(query) {
    left_joins_clientable
      .left_joins(:causale)
      .where(
        "scuole.denominazione ILIKE :q OR clienti.denominazione ILIKE :q OR documenti.referente ILIKE :q OR causali.causale ILIKE :q",
        q: "%#{query}%"
      )
  }

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

  # Scope per stato Entry-based (unified triage system)
  # Attivi = documenti senza closure (non completati)
  scope :attivi, -> {
    where("documenti.id IN (SELECT e.entryable_id::uuid FROM entries e LEFT JOIN closures c ON c.entry_id = e.id WHERE e.entryable_type = 'Documento' AND c.id IS NULL)")
  }
  scope :completati, -> {
    where("documenti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN closures c ON c.entry_id = e.id WHERE e.entryable_type = 'Documento')")
  }

  def to_combobox_display
    [causale&.causale, referente].compact.join(" - ")
  end

  def self.form_steps
    {
      tipo_documento: %i[causale_id numero_documento data_documento clientable_type clientable_id tipo_pagamento_previsto],
      cliente: %i[clientable_type clientable_id referente note],
      dettaglio: [documento_righe_attributes:
                    [:id, :posizione,
                     { riga_attributes: %i[id libro_id quantita prezzo prezzo_cents prezzo_copertina_cents sconto iva_cents _destroy] }]]
    }
  end

  def required_for_step?(step)
    return true if form_step.nil?

    ordered_keys = self.class.form_steps.keys.map(&:to_sym)
    !!(ordered_keys.index(step) <= ordered_keys.index(form_step))
  end

  def clientable
    super || Domain::NessunCliente.new
  end

  def incompleto?
    causale.blank? || clientable.is_a?(Domain::NessunCliente)
  end

  def tappa_target
    return nil if clientable.is_a?(Domain::NessunCliente)
    clientable.respond_to?(:tappa_target) ? clientable.tappa_target : nil
  end

  def default_titolo_tappa
    [causale&.causale, numero_documento].compact.join(" ").strip.presence
  end

  def vendita?
    tipo_movimento == 'vendita'
  end

  # Bozza senza causale: il pagamento resta applicabile finché non si sa la causale
  def pagamento_applicabile?
    causale.nil? || causale.gestione_pagamento?
  end

  # Bozza senza causale: la consegna resta applicabile finché non si sa la causale
  def consegna_applicabile?
    causale.nil? || causale.gestione_consegna?
  end

  def mostra_importo?
    causale.nil? || causale.mostra_importo?
  end

  def registrato?
    %w[TD01 TD04 TD24].include?(causale.causale)
  end

  # I metodi pagato?, pagato_il, consegnato?, consegnato_il, tipo_pagamento
  # sono ora forniti dai concern Pagabile e Consegnabile

  def totale_importo
    return totale_cents / 100.0 if totale_cents.present?
    righe.sum(&:importo) + (spese_cents || 0) / 100.0
  end

  def totale_copie
    return super if super.present?
    righe.sum(&:quantita)
  end

  def ricalcola_totali!
    totale_importo_calcolato = righe.sum(&:importo_cents).round + (spese_cents || 0)
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
    causale.causali_successive.map(&:to_s).include?(causale_target.id.to_s) ||
      causale.causali_successive.map(&:to_s).include?(causale_target.causale.to_s)
  end

  def genera_documento_derivato(causale_nuova, attributes = {})
    nuovo = self.class.new(
      # Il nuovo documento NON ha padre (è il documento principale)
      derivato_da_causale: self.causale,
      causale: causale_nuova,
      clientable: clientable,
      user: user,
      data_documento: Date.today
    )

    nuovo.assign_attributes(attributes)

    # Condividi le righe del documento origine (stesse righe, nuovo DocumentoRiga)
    documento_righe.each do |doc_riga|
      nuovo.documento_righe.build(
        riga: doc_riga.riga,
        posizione: doc_riga.posizione
      )
    end

    nuovo
  end

  # Eredita consegna e pagamento dai documenti origine (se tutti hanno lo stesso stato)
  # Salta i documenti non applicabili invece di esplodere sulla guardia.
  def eredita_stato_da_origini(documenti_origine)
    if consegna_applicabile? && documenti_origine.all?(&:consegnato?)
      mark_consegnato(consegnato_il: documenti_origine.map(&:consegnato_il).compact.max)
    end

    if pagamento_applicabile? && documenti_origine.all?(&:pagato?)
      mark_pagato(
        pagato_il: documenti_origine.map(&:pagato_il).compact.max,
        tipo_pagamento: documenti_origine.first.tipo_pagamento
      )
    end
  end

  # Chiamato da Consegnabile/Pagabile a ogni variazione di consegne/pagamenti
  def auto_close_se_completo
    close if (consegnato? || !consegna_applicabile?) && (pagato? || !pagamento_applicabile?) && !closed?
  end

  # Ricalcola la giacenza di tutti i libri toccati da questo documento
  def ricalcola_giacenze_libri
    Libro.where(id: righe.select(:libro_id)).find_each(&:ricalcola_giacenza!)
  end

  # Chiamato da Pagabile quando il documento risulta interamente pagato:
  # i figli vengono saldati col tipo dell'ultimo acconto
  def pagamento_saturato
    ultimo = pagamenti.order(:pagato_il).last
    tutti_i_discendenti.each do |figlio|
      figlio.mark_pagato(user: ultimo&.user || Current.user, tipo_pagamento: ultimo&.tipo_pagamento)
    end
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

  # Consegna parziale con chiavi ISBN o libro_id, per CLI e MCP che non
  # conoscono i documento_riga id
  def consegna_parziale_per_libro!(quantita_per_libro, **opzioni)
    mappa = quantita_per_libro.to_h.each_with_object({}) do |(chiave, quantita), accumulatore|
      chiave = chiave.to_s.delete("- ")
      documento_riga = documento_righe.joins(riga: :libro).find_by(libri: { codice_isbn: chiave }) ||
                       documento_righe.joins(:riga).find_by(righe: { libro_id: chiave })
      raise ArgumentError, "nessuna riga del documento con libro #{chiave}" unless documento_riga
      accumulatore[documento_riga.id] = quantita.to_i
    end
    consegna_parziale!(mappa, **opzioni)
  end

  # Righe consegnabili direttamente da questo documento: residuo positivo e
  # riga non condivisa con un documento derivato (quella si consegna dal derivato)
  def documento_righe_consegnabili
    righe_derivati_ids = tutti_i_discendenti.flat_map { |figlio| figlio.righe.ids }
    documento_righe.includes(riga: :libro).select do |documento_riga|
      residui_per_documento_riga[documento_riga.id].to_i.positive? &&
        !righe_derivati_ids.include?(documento_riga.riga_id)
    end
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

  # Aggiunge le righe di questo documento a uno esistente (condivide le stesse righe)
  def aggiungi_righe_a(documento_target)
    transaction do
      documento_righe.each do |doc_riga|
        documento_target.documento_righe.create!(riga: doc_riga.riga)
      end

      # Imposta questo documento come figlio del target
      update!(documento_padre: documento_target)
    end
    documento_target
  end

  # Documenti dello stesso cliente con causali predecessori, attivi, senza padre
  def documenti_collegabili
    return Documento.none unless causale
    causali_pred = Causale.predecessori_di(causale)
    return Documento.none if causali_pred.empty?

    Documento.where(causale: causali_pred)
      .where(clientable_type: clientable_type, clientable_id: clientable_id)
      .where(account_id: account_id)
      .where(documento_padre_id: nil)
      .where.not(id: id)
      .attivi
      .includes(:causale, :entry)
      .order(data_documento: :desc)
  end

  # Collega un documento figlio: copia le righe, chiude il figlio, ricalcola totali
  def collega_documento_figlio(doc_figlio)
    transaction do
      doc_figlio.aggiungi_righe_a(self)
      doc_figlio.close unless doc_figlio.closed?
      doc_figlio.ensure_entry!
      reload
      ricalcola_totali!
      ensure_entry!
    end
  end

  # Scollega un documento derivato dal padre: rimuove le righe condivise dal padre e riapre il figlio
  def scollega_documento_derivato(doc_derivato)
    transaction do
      # Rimuovi dal padre le DocumentoRiga che puntano a righe condivise col figlio
      righe_figlio_ids = doc_derivato.righe.pluck(:id)
      documento_righe.where(riga_id: righe_figlio_ids).destroy_all

      # Scollega il figlio
      doc_derivato.update!(documento_padre_id: nil)

      # Riapri il figlio
      doc_derivato.reopen if doc_derivato.closed?
      doc_derivato.ensure_entry!

      # Ricalcola totali del padre
      reload
      ricalcola_totali!
      ensure_entry!
    end
  end

  private

  # Ricalcola totali dopo creazione (dopo commit, quando tutte le righe sono nel DB)
  def ricalcola_totali_dopo_creazione
    righe.reset
    ricalcola_totali!
  end

  # Ricalcola i totali se ci sono righe ma i totali non sono impostati
  def ricalcola_totali_se_necessario
    return if documento_righe.empty?
    return if totale_cents.present? && totale_cents > 0

    totale_importo_calcolato = righe.sum(&:importo_cents) + (spese_cents || 0)
    totale_copie_calcolato = righe.sum(&:quantita)

    self.totale_cents = totale_importo_calcolato
    self.totale_copie = totale_copie_calcolato
  end

  # Chiude automaticamente documenti figli (es. DDT derivato da TD01)
  def close_if_has_padre
    return unless documento_padre_id.present?

    ensure_entry!
    close unless closed?
  end

  def memorizza_libri_per_giacenza
    @libri_da_ricalcolare = righe.pluck(:libro_id).uniq
  end

  def ricalcola_giacenze_libri_memorizzati
    Libro.where(id: @libri_da_ricalcolare.to_a).find_each(&:ricalcola_giacenza!)
  end

  # Riapre i documenti figli quando il padre viene eliminato
  def riapri_documenti_figli
    documenti_derivati.each do |figlio|
      figlio.reopen if figlio.closed?
    end
  end

  # Override from Entryable - auto-create entry for new documenti
  def should_auto_create_entry?
    true
  end

end
