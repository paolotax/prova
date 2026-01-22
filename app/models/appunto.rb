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
#  stato              :string
#  team               :string
#  telefono           :string
#  totale_cents       :integer          default(0)
#  totale_copie       :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :uuid
#  appuntabile_id     :uuid
#  classe_id          :bigint
#  import_adozione_id :bigint
#  import_scuola_id   :bigint
#  user_id            :bigint           not null
#  voice_note_id      :bigint
#
# Indexes
#
#  index_appunti_on_account_id                           (account_id)
#  index_appunti_on_account_id_and_created_at            (account_id,created_at)
#  index_appunti_on_appuntabile_type_and_appuntabile_id  (appuntabile_type,appuntabile_id)
#  index_appunti_on_classe_id                            (classe_id)
#  index_appunti_on_id                                   (id) UNIQUE
#  index_appunti_on_import_adozione_id                   (import_adozione_id)
#  index_appunti_on_import_scuola_id                     (import_scuola_id)
#  index_appunti_on_user_id                              (user_id)
#  index_appunti_on_voice_note_id                        (voice_note_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (voice_note_id => voice_notes.id)
#

class Appunto < ApplicationRecord
  # Entryable concern for unified triage system
  include Entryable

  # State Record concerns (legacy - kept for backward compatibility during migration)
  include Golden         # has_one :goldness
  include Closeable      # has_one :closure
  include Postponable    # has_one :not_now
  include Consegnabile   # has_one :consegna
  include Pagabile       # has_one :pagamento
  include Registrabile   # has_one :registrazione

  belongs_to :account
  belongs_to :import_scuola, required: false
  belongs_to :user
  belongs_to :import_adozione, required: false
  belongs_to :classe, class_name: 'Views::Classe', optional: true
  belongs_to :appuntabile, polymorphic: true, optional: true

  # Righe libri (stesso pattern di Documento)
  has_many :appunto_righe, dependent: :destroy
  has_many :righe, through: :appunto_righe
  accepts_nested_attributes_for :appunto_righe, allow_destroy: true

  validates :account_id, presence: true
  before_validation :set_account_from_current, on: :create

  has_one_attached :image
  has_many_attached :attachments
  has_rich_text :content

  has_many :tappe, as: :tappable

  belongs_to :voice_note, optional: true

  include PgSearch::Model

  search_fields = %i[nome body email telefono stato]

  pg_search_scope :search_all_word,
                  against: search_fields,
                  associated_against: {
                    import_scuola: %i[CODICESCUOLA DENOMINAZIONESCUOLA DESCRIZIONECOMUNE],
                    import_adozione: %i[CODICESCUOLA CODICEISBN EDITORE],
                    rich_text_content: [:body],
                    attachments_blobs: [:filename]
                  },
                  using: {
                    tsearch: { any_word: false, prefix: true }
                  }

  # Scope semplificato per filtri (evita problemi UUID con Action Text)
  pg_search_scope :search_basic,
                  against: search_fields,
                  associated_against: {
                    import_scuola: %i[CODICESCUOLA DENOMINAZIONESCUOLA DESCRIZIONECOMUNE],
                    import_adozione: %i[CODICESCUOLA CODICEISBN EDITORE]
                  },
                  using: {
                    tsearch: { any_word: false, prefix: true }
                  }

  include Searchable

  search_on :nome, :body, :email, :telefono, :stato,
            import_adozione: %i[CODICESCUOLA CODICEISBN EDITORE],
            rich_text_content: [:body],
            attachments_blobs: [:filename],
            import_scuola: %i[CODICESCUOLA DENOMINAZIONESCUOLA DESCRIZIONECOMUNE DESCRIZIONECARATTERISTICASCUOLA DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA CODICEISTITUTORIFERIMENTO DENOMINAZIONEISTITUTORIFERIMENTO]


  STATO_APPUNTI = ['da fare', 'in evidenza', 'in settimana', 'in visione', 'da pagare', 'completato', 'archiviato']

  # State Records Fizzy (chiave => label italiano)
  FIZZY_STATES = {
    'golden'     => 'In evidenza',
    'closed'     => 'Chiuso',
    'postponed'  => 'Rimandato',
    'consegnato' => 'Consegnato',
  }.freeze

  delegate :denominazione, :comune, to: :import_scuola, allow_nil: true

  scope :non_saggi, -> { where.not(nome: %w[saggio seguito kit]) }

  # scope :da_fare, -> { where(stato: 'da fare').non_saggi }
  # scope :in_evidenza, -> { where(stato: 'in evidenza').non_saggi }
  # scope :in_settimana, -> { where(stato: 'in settimana').non_saggi }
  # scope :da_pagare, -> { where(stato: 'da pagare').non_saggi }
  # scope :in_visione, -> { where(stato: 'in visione').non_saggi }
  # scope :completati, -> { where(stato: 'completato').non_saggi }

  # scope :archiviati, -> { where(stato: 'archiviato').non_saggi }

  # scope :da_completare, -> { where(stato: ['da fare', 'in evidenza', 'in settimana']).non_saggi }
  # scope :in_sospeso, -> { where(stato: ['in visione', 'da pagare']).non_saggi }
  scope :non_archiviati, -> { where.not(stato: %w[archiviato]).non_saggi }

  # Scope per filtrare per State Records Fizzy (OR logic tra stati selezionati)
  scope :with_any_state, ->(states) {
    return all if states.blank?

    subqueries = []
    subqueries << Goldness.where(goldenable_type: 'Appunto').select(:goldenable_id) if states.include?('golden')
    subqueries << Closure.where(closeable_type: 'Appunto').select(:closeable_id) if states.include?('closed')
    subqueries << NotNow.where(not_nowable_type: 'Appunto').select(:not_nowable_id) if states.include?('postponed')
    subqueries << Consegna.where(consegnabile_type: 'Appunto').select(:consegnabile_id) if states.include?('consegnato')
    subqueries << Pagamento.where(pagabile_type: 'Appunto').select(:pagabile_id) if states.include?('pagato')
    subqueries << Registrazione.where(registrabile_type: 'Appunto').select(:registrabile_id) if states.include?('registrato')

    return all if subqueries.empty?
    where(id: subqueries.reduce { |union, sq| union.union(sq) })
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
end
