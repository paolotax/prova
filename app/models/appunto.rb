# == Schema Information
#
# Table name: appunti
#
#  id                 :uuid             not null, primary key
#  active             :boolean
#  appuntabile_type   :string
#  body               :text
#  completed_at       :datetime
#  email              :string
#  nome               :string
#  numero             :integer
#  stato              :string
#  status             :string           default("drafted"), not null
#  team               :string
#  telefono           :string
#  totale_cents       :integer          default(0)
#  totale_copie       :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :uuid
#  appuntabile_id     :uuid
#  classe_id          :uuid
#  import_adozione_id :bigint
#  import_scuola_id   :bigint
#  user_id            :bigint           not null
#  voice_note_id      :bigint
#
# Indexes
#
#  index_appunti_on_account_id                            (account_id)
#  index_appunti_on_account_id_and_created_at             (account_id,created_at)
#  index_appunti_on_account_id_and_numero_and_created_at  (account_id,numero,created_at)
#  index_appunti_on_account_id_and_status                 (account_id,status)
#  index_appunti_on_appuntabile_type_and_appuntabile_id   (appuntabile_type,appuntabile_id)
#  index_appunti_on_classe_id                             (classe_id)
#  index_appunti_on_id                                    (id) UNIQUE
#  index_appunti_on_import_adozione_id                    (import_adozione_id)
#  index_appunti_on_import_scuola_id                      (import_scuola_id)
#  index_appunti_on_user_id                               (user_id)
#  index_appunti_on_voice_note_id                         (voice_note_id)
#
# Foreign Keys
#
#  fk_rails_...  (classe_id => classi.id)
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (voice_note_id => voice_notes.id)
#

class Appunto < ApplicationRecord
  # Entryable concern for unified triage system
  include Entryable

  # Draft/published status (Fizzy pattern)
  include Appunto::Statuses

  # Turbo broadcasts for real-time updates
  include Appunto::Broadcastable

  # State Record concerns - ora tutti via Entry delegation (Entryable)
  # Golden rimosso: usa Entry::Golden via gild/ungild
  # Closeable rimosso: usa Entry::Closeable via close/reopen
  # Postponable rimosso: usa Entry::Postponable via postpone/resume
  include Consegnabile   # has_one :consegna
  include Pagabile       # has_one :pagamento
  include Registrabile   # has_one :registrazione

  belongs_to :account
  belongs_to :import_scuola, required: false
  belongs_to :user
  belongs_to :import_adozione, required: false
  belongs_to :classe, optional: true
  belongs_to :appuntabile, polymorphic: true, optional: true

  # Virtual attribute per combobox multi-entità
  # Formato: "Scuola:uuid" o "Cliente:id"
  attr_accessor :appuntabile_value

  def appuntabile_value
    return nil unless appuntabile.present?

    appuntabile.to_appuntabile_value
  end

  def appuntabile_value=(value)
    return if value.blank?

    klass, id = Appuntabile.parse_appuntabile_value(value)
    if klass && id
      # Gestisce sia UUID che vecchi ID interi (per backward compatibility)
      begin
        self.appuntabile = klass.find_by(id: id)
      rescue ActiveRecord::StatementInvalid => e
        # Se l'ID non è compatibile (es. integer su colonna UUID), ignora
        Rails.logger.warn "Invalid appuntabile_value format: #{value} - #{e.message}"
        nil
      end
    end
  end

  # Righe libri (stesso pattern di Documento)
  has_many :appunto_righe, dependent: :destroy
  has_many :righe, through: :appunto_righe
  accepts_nested_attributes_for :appunto_righe, allow_destroy: true

  validates :account_id, presence: true
  before_validation :set_account_from_current, on: :create
  before_create :assegna_numero

  has_one_attached :image
  has_many_attached :attachments
  has_rich_text :content

  has_many :tappe, as: :tappable

  belongs_to :voice_note, optional: true

  # State Records Fizzy (chiave => label italiano)
  FIZZY_STATES = {
    'attivi'      => 'Attivi',
    'in_evidenza' => 'In evidenza',
    'rimandati'   => 'Rimandati',
    'completati'  => 'Completati',
  }.freeze

  delegate :denominazione, :comune, to: :import_scuola, allow_nil: true

  scope :non_saggi, -> { where.not(nome: %w[saggio seguito kit]).or(where(nome: nil)) }

  # LEFT JOIN per ricerca su polymorphic appuntabile (Scuola, Cliente, Classe) e Action Text content
  scope :left_joins_appuntabile, -> {
    joins(<<~SQL)
      LEFT JOIN scuole ON appunti.appuntabile_type = 'Scuola' AND appunti.appuntabile_id = scuole.id
      LEFT JOIN clienti ON appunti.appuntabile_type = 'Cliente' AND appunti.appuntabile_id = clienti.id
      LEFT JOIN classi ON appunti.appuntabile_type = 'Classe' AND appunti.appuntabile_id = classi.id
      LEFT JOIN scuole AS scuole_classe ON classi.scuola_id = scuole_classe.id
      LEFT JOIN action_text_rich_texts ON action_text_rich_texts.record_type = 'Appunto'
        AND action_text_rich_texts.record_id = appunti.id::text
        AND action_text_rich_texts.name = 'content'
    SQL
  }

  # scope :da_fare, -> { where(stato: 'da fare').non_saggi }
  # scope :in_evidenza, -> { where(stato: 'in evidenza').non_saggi }
  # scope :in_settimana, -> { where(stato: 'in settimana').non_saggi }
  # scope :da_pagare, -> { where(stato: 'da pagare').non_saggi }
  # scope :in_visione, -> { where(stato: 'in visione').non_saggi }
  # scope :completati, -> { where(stato: 'completato').non_saggi }

  # scope :archiviati, -> { where(stato: 'archiviato').non_saggi }

  # scope :da_completare, -> { where(stato: ['da fare', 'in evidenza', 'in settimana']).non_saggi }
  # scope :in_sospeso, -> { where(stato: ['in visione', 'da pagare']).non_saggi }
  # Scope per stato Entry-based (unified triage system)
  # Gli state records (goldness, closure, not_now) sono su Entry, non su Appunto
  # Nomi allineati a FIZZY_STATES per coerenza UI
  scope :attivi, -> {
    where("appunti.id IN (SELECT e.entryable_id::uuid FROM entries e LEFT JOIN closures c ON c.entry_id = e.id WHERE e.entryable_type = 'Appunto' AND c.id IS NULL)")
  }
  scope :completati, -> {
    where("appunti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN closures c ON c.entry_id = e.id WHERE e.entryable_type = 'Appunto')")
  }
  scope :rimandati, -> {
    where("appunti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN not_nows n ON n.entry_id = e.id WHERE e.entryable_type = 'Appunto')")
  }
  scope :in_evidenza, -> {
    where("appunti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN goldnesses g ON g.entry_id = e.id WHERE e.entryable_type = 'Appunto')")
  }

  scope :with_any_state, ->(states) {
    return all if states.blank?

    conditions = []

    # Attivi: hanno entry senza closure
    if states.include?('attivi')
      conditions << "appunti.id IN (SELECT e.entryable_id::uuid FROM entries e LEFT JOIN closures c ON c.entry_id = e.id WHERE e.entryable_type = 'Appunto' AND c.id IS NULL)"
    end

    # In evidenza: hanno entry con goldness
    if states.include?('in_evidenza')
      conditions << "appunti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN goldnesses g ON g.entry_id = e.id WHERE e.entryable_type = 'Appunto')"
    end

    # Rimandati: hanno entry con not_now
    if states.include?('rimandati')
      conditions << "appunti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN not_nows n ON n.entry_id = e.id WHERE e.entryable_type = 'Appunto')"
    end

    # Completati: hanno entry con closure
    if states.include?('completati')
      conditions << "appunti.id IN (SELECT e.entryable_id::uuid FROM entries e INNER JOIN closures c ON c.entry_id = e.id WHERE e.entryable_type = 'Appunto')"
    end

    return all if conditions.empty?
    where(conditions.join(' OR '))
  }

  # Goldness-first ordering: SQL fragment for ORDER BY
  # Golden items (NOT EXISTS = false) sort before non-golden (true)
  GOLDEN_SORT_SQL = <<~SQL.squish
    (NOT EXISTS (
      SELECT 1 FROM entries e
      JOIN goldnesses g ON g.entry_id = e.id
      WHERE e.entryable_type = 'Appunto' AND e.entryable_id = appunti.id::text
    ))
  SQL

  scope :with_golden_first, -> {
    order(Arel.sql(GOLDEN_SORT_SQL))
  }

  # non includono clienti REFACTOR appunto clientable
  # scope :nel_baule_di_oggi, lambda {
  #   where(import_scuola_id: Current.user.tappe.di_oggi.where(tappable_type: 'ImportScuola').pluck(:tappable_id))
  # }
  # scope :nel_baule_di_domani, lambda {
  #   where(import_scuola_id: Current.user.tappe.di_domani.where(tappable_type: 'ImportScuola').pluck(:tappable_id))
  # }
  # scope :nel_baule_del_giorno, lambda { |day|
  #   where(import_scuola_id: Current.user.tappe.del_giorno(day).where(tappable_type: 'ImportScuola').pluck(:tappable_id))
  # }

  # scope :saggi, -> { where(nome: 'saggio').where.not(import_adozione_id: nil) }
  # scope :seguiti, -> { where(nome: 'seguito').where.not(import_adozione_id: nil) }
  # scope :kit, -> { where(nome: 'kit').where.not(import_adozione_id: nil) }
  # scope :ssk, -> { where(nome: %w[saggio seguito kit]).where.not(import_adozione_id: nil) }
  
  scope :saggi, -> { where(nome: 'saggio') }
  scope :seguiti, -> { where(nome: 'seguito') }
  scope :kit, -> { where(nome: 'kit') }
  scope :ssk, -> { where(nome: %w[saggio seguito kit]) }

  def self.ransackable_attributes(auth_object = nil)
    %w[nome body]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[nome body]
  end

  def scuola
    import_scuola
  end

  def content_to_s
    content.to_s.gsub('<div class="trix-content">', '')
           .gsub('</div>', '')
           .gsub('<div>', '')
           .gsub('</br>', '')
           .gsub('<p>', '')
           .gsub('</p>', '')
           .gsub('<div>', '')
           .gsub('</div>', '')
           .gsub('<br/>', '')
           .gsub('</br/>', '')
           .gsub('<p/>', '')
           .gsub('</p/>', '')
           .gsub('<div/>', '')
           .gsub('</div/>', '')
           .gsub('<br />', '')
           .gsub('</br />', '')
           .gsub('<p />', '')
           .gsub('</p />', '')
           .gsub('<div />', '')
           .gsub('</div />', '')
  end

  def nome_e_classe
    if nome.present? && classe.present?
      "#{nome} - #{classe.to_combobox_display}"
    elsif nome.present?
      nome
    elsif classe.present?
      classe.to_combobox_display
    else
      ''
    end
  end

  def image_as_thumbnail
    return unless image.content_type.in?(%w[image/jpeg image/png image/jpg image/gif image/webp])

    image.variant(resize_to_limit: [300, 300]).processed
  end

  def appunto_attachment(index)
    target = attachments[index]
    return unless attachments.attached?

    if target.image?
      target.variant(resize_to_limit: [200, 200]).processed
    elsif target.video?
      target.variant(resize_to_limit: [200, 200]).processed
    end
  end

  def representables_attachments
    representables_attachments = []
    if attachments.attached?
      attachments.each do |att|
        representables_attachments << att if att.representable?
      end
    end
    representables_attachments
  end

  def file_attachments
    file_attachments = []
    if attachments.attached?
      attachments.each do |att|
        file_attachments << att unless att.representable?
      end
    end
    file_attachments
  end

  def self.nel_baule
    appunti_scuole_di_oggi = Appunto.where(import_scuola_id: Tappa.di_oggi.where(tappable_type: 'ImportScuola').pluck(:tappable_id))
    # appunti_adozioni_di_oggi = Appunto.where(import_adozione_id: Tappa.di_oggi.where(tappable_type: "ImportAdozione").pluck(:tappable_id))
    # appunti_scuole_di_oggi.or(appunti_adozioni_di_oggi)
  end

  def is_saggio?
    nome == 'saggio' && import_adozione.present?
  end

  def is_seguito?
    nome == 'seguito' && import_adozione.present?
  end

  def is_kit?
    nome == 'kit' && import_adozione.present?
  end

  def is_ssk?
    %w[saggio seguito kit].include?(nome) && import_adozione.present?
  end

  # Calcoli totali righe
  def ricalcola_totali!
    self.totale_copie = righe.sum(:quantita)
    self.totale_cents = righe.sum(&:importo_cents)
    save!
  end

  def totale
    totale_cents / 100.0
  end

  def numero_formattato
    return nil unless numero.present?
    "#{numero}-#{created_at.strftime('%y')}"
  end

  # Override legacy Golden/Closeable/Postponable methods to use Entry-based system
  # These must come after the includes to take precedence
  def golden?
    entry&.golden? || false
  end

  def closed?
    entry&.closed? || false
  end

  def postponed?
    entry&.postponed? || false
  end

  def open?
    !closed?
  end

  def gild(user: Current.user)
    entry&.gild(user: user)
  end

  def ungild
    entry&.ungild
  end

  def close(user: Current.user)
    entry&.close(user: user)
  end

  def reopen(user: Current.user)
    entry&.reopen(user: user)
  end

  def postpone(user: Current.user)
    entry&.postpone(user: user)
  end

  def resume
    entry&.resume
  end

  private

  def set_account_from_current
    self.account ||= Current.account
  end

  def assegna_numero
    return if numero.present?

    anno_corrente = Time.current.year
    inizio_anno = Time.zone.local(anno_corrente, 1, 1).beginning_of_day
    fine_anno = Time.zone.local(anno_corrente, 12, 31).end_of_day

    ultimo_numero = account.appunti
      .where(created_at: inizio_anno..fine_anno)
      .maximum(:numero) || 0

    self.numero = ultimo_numero + 1
  end

  # Override from Entryable - auto-create entry for new appunti
  def should_auto_create_entry?
    true
  end
end
