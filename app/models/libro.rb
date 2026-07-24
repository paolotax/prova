# == Schema Information
#
# Table name: libri
#
#  id                     :bigint           not null, primary key
#  adozioni_count         :integer          default(0), not null
#  classe                 :integer
#  cm                     :string
#  codice_isbn            :string
#  collana                :string
#  confezioni_count       :integer          default(0), not null
#  disciplina             :string
#  fascicoli_count        :integer          default(0), not null
#  note                   :text
#  numero_fascicoli       :integer
#  prezzo_in_cents        :integer
#  prezzo_suggerito_cents :integer          default(0)
#  slug                   :string
#  titolo                 :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :uuid             not null
#  categoria_id           :bigint           not null
#  editore_id             :bigint
#  prosegue_in_id         :bigint
#  user_id                :bigint           not null
#
# Indexes
#
#  index_libri_on_account_id                 (account_id)
#  index_libri_on_account_id_and_created_at  (account_id,created_at)
#  index_libri_on_categoria_id               (categoria_id)
#  index_libri_on_classe_and_disciplina      (classe,disciplina)
#  index_libri_on_cm                         (cm)
#  index_libri_on_editore_id                 (editore_id)
#  index_libri_on_prosegue_in_id             (prosegue_in_id)
#  index_libri_on_slug                       (slug) UNIQUE
#  index_libri_on_user_id                    (user_id)
#  index_libri_on_user_id_and_codice_isbn    (user_id,codice_isbn)
#  index_libri_on_user_id_and_collana        (user_id,collana)
#  index_libri_on_user_id_and_editore_id     (user_id,editore_id)
#  index_libri_on_user_id_and_titolo         (user_id,titolo)
#
# Foreign Keys
#
#  fk_rails_...  (categoria_id => categorie.id)
#  fk_rails_...  (editore_id => editori.id)
#  fk_rails_...  (user_id => users.id)
#
class Libro < ApplicationRecord
  include AccountScoped
  include Copertina

  include FriendlyId
  friendly_id :slug_candidates, use: :slugged
  def slug_candidates
    [
      :titolo,
      [:titolo, :user_id],
      [:titolo, :user_id, :codice_isbn],
    ]
  end

  include Searchable
  search_on :titolo, :codice_isbn, :cm, :disciplina, :note, :collana, editore: :editore, categoria: :nome_categoria

  include PgSearch::Model
  search_fields =  [ :titolo, :disciplina, :codice_isbn, :collana, :note, :cm ]
  pg_search_scope :search_all_word,
                        against: search_fields,
                        associated_against: {
                          editore: [:editore],
                          categoria: [:nome_categoria]
                        },
                        using: {
                          tsearch: { any_word: false, prefix: true }
                        }

  belongs_to :user
  belongs_to :editore, optional: true
  belongs_to :categoria

  belongs_to :prosegue_in, class_name: "Libro", optional: true
  # FK non univoca: se piu' volumi convergono sullo stesso successore, has_one ne sceglie uno.
  has_one :precedente, class_name: "Libro", foreign_key: :prosegue_in_id, inverse_of: :prosegue_in
  
  has_one :giacenza, dependent: :destroy
  
  has_many :confezione_righe, foreign_key: :confezione_id, class_name: "ConfezioneRiga",
           dependent: :destroy, inverse_of: :confezione
  has_many :fascicoli, through: :confezione_righe

  has_many :fascicolo_righe, foreign_key: :fascicolo_id, class_name: "ConfezioneRiga",
           dependent: :destroy, inverse_of: :fascicolo
  has_many :confezioni, through: :fascicolo_righe
  
  accepts_nested_attributes_for :confezione_righe

  has_many :righe
  has_many :documenti, through: :righe
  has_many :documento_righe, through: :righe

  # Crea-o-ricalcola la giacenza per questo libro (pattern saldo!)
  def ricalcola_giacenza!
    return if Giacenza.ricalcolo_sospeso
    Giacenza.find_or_create_by!(account_id: account_id, libro_id: id).ricalcola!
  end

  normalizes :disciplina, with: ->(d) { d.upcase }

  validates :titolo, presence: true
  #validates :editore, presence: true
  
  validates :prezzo_in_cents, presence: true
  
  validates :codice_isbn, presence: true, uniqueness: { scope: :account_id }

  belongs_to :edizione_titolo, primary_key: :codice_isbn, foreign_key: :codice_isbn, optional: true
  
  scope :no_fascicoli, -> { where(fascicoli_count: 0) }
  scope :no_confezioni, -> { where(confezioni_count: 0) }
  scope :with_fascicoli, -> { where("fascicoli_count > 0") }
  scope :with_confezioni, -> { where("confezioni_count > 0") }

  scope :lista, -> { where("confezioni_count = 0 or fascicoli_count > 0") }

  # Libri eleggibili a fascicolo di questa confezione: non confezioni essi stessi,
  # esclusa la confezione corrente e i fascicoli GIA' presenti in QUESTA confezione.
  # NB: un fascicolo puo' appartenere a piu' confezioni, quindi NON si escludono
  # i libri gia' fascicoli di altre confezioni.
  scope :fascicoli_candidati_per, ->(libro) {
    esclusi = [libro.id, *libro.fascicoli.pluck(:id)]
    no_fascicoli.where.not(id: esclusi)
  }

  # Parole che NON identificano la serie ma il tipo/qualifica di confezione.
  NOISE_TITOLO = %w[CL CONF VEND CONFVEND CONFEZIONE VOL TOMO PACK KIT SET
                    METODO EDIZIONE ED PROP].freeze

  # Token-serie: le parole iniziali significative del titolo, fino al primo
  # numero / abbreviazione / parola-rumore. Es: "BOSCO ALLEGRO CL. 1 CONF.
  # VEND. METODO 4 CARATTERI" => ["BOSCO", "ALLEGRO"].
  def self.serie_tokens(titolo)
    tokens = []
    titolo.to_s.upcase.split(/[\s\-]+/).each do |parola|
      pulita = parola.gsub(/[^[:alnum:]]/, "")
      break if pulita.match?(/\d/) || NOISE_TITOLO.include?(pulita)
      next  if pulita.length < 3
      tokens << pulita
    end
    tokens
  end

  scope :potenziali_fascicoli_di, ->(libro) {
    tokens = serie_tokens(libro.titolo)
    next none if tokens.empty?

    rel = fascicoli_candidati_per(libro)
    tokens.each { |t| rel = rel.where("titolo ILIKE ?", "%#{t}%") }
    rel
  }
  
  before_save :init
  def init
    self.prezzo_in_cents ||= 0
  end

  before_save :assegna_prezzo_ministeriale
  def assegna_prezzo_ministeriale
    return unless classe_changed? || disciplina_changed?
    return if prezzo_in_cents.present? && prezzo_in_cents > 0 && !prezzo_in_cents_was&.zero?

    if classe.present? && disciplina.present?
      prezzo = PrezzoMinisteriale.prezzo_per(classe: classe.to_s, disciplina: disciplina.upcase)
      self.prezzo_in_cents = prezzo if prezzo
    end
  end


  # before_save :update_numero_fascicoli
  # def update_numero_fascicoli
  #   self.numero_fascicoli = fascicoli.size
  # end
    

  def can_delete?
    righe.empty?
  end

  def has_fascicoli?
    fascicoli_count > 0
  end

  def has_confezioni?
    confezioni.size > 0
  end

  def self.categorie
    Categoria.order(:nome_categoria).pluck(:nome_categoria)
  end

  def categoria=(value)
    if value.is_a?(String)
      super(Categoria.resolve(value, account: account || Current.account))
    else
      super
    end
  end

  def to_combobox_display
    self.titolo
  end

  # Candidati volume successivo: stesso account e categoria, classe + 1, stesso
  # titolo-base e stessa disciplina ministeriale. Eccezione primo biennio:
  # IL LIBRO DELLA PRIMA CLASSE scorre nel SUSSIDIARIO (1° BIENNIO).
  # La collana non è affidabile: non si usa. Usato dall'auto-link
  # (Libro::CollegaProsegui): deve restare STRETTO — i casi laschi passano
  # dalla select (opzioni_prosegui).
  def candidati_prosegui
    return [] if classe.blank? || titolo.blank?

    scope = Libro.where(account_id: account_id, categoria_id: categoria_id, classe: classe + 1)
    scope = scope.where(disciplina: discipline_prosegui) if disciplina.present?
    base = titolo_base
    scope.select { |l| l.titolo_base == base }
  end

  # Opzioni per la select "prosegue in": tutti i libri di categoria + classe+1
  # (decine, non l'intero catalogo), coi più simili per titolo in testa. La
  # somiglianza è il prefisso comune dei titoli normalizzati: nei dati reali le
  # discipline derivano (LETTURE → ITALIANO) e i suffissi cambiano (CONF. PROP.
  # vs CONFEZIONE VENDITA), quindi qui niente filtri duri.
  def opzioni_prosegui
    return [] if classe.blank?

    base = titolo_base
    Libro.where(account_id: account_id, categoria_id: categoria_id, classe: classe + 1)
         .sort_by { |l| [-prefisso_comune(base, l.titolo_base), l.titolo.to_s] }
  end

  # Titolo normalizzato senza numeri di volume: maiuscolo, punteggiatura via,
  # numeri a 1-2 cifre rimossi OVUNQUE ("BANDA DEL BUS 1 MATEMATICA" →
  # "BANDA DEL BUS MATEMATICA"); i numeri lunghi (annate tipo "STORIA 2000")
  # restano perché non sono volumi. Class method condiviso: usato anche da
  # Miur::VolumeSuccessivo per confrontare i titoli dei roster MIUR.
  def self.titolo_base(str)
    str.to_s.upcase.gsub(/[^A-Z0-9 ]/, " ").gsub(/\b\d{1,2}\b/, " ").squeeze(" ").strip
  end

  def titolo_base
    self.class.titolo_base(titolo)
  end

  def prezzo
    if prezzo_in_cents 
      prezzo_in_cents/ 100.0
    else
      0.0
    end
  end

  def prezzo=(prezzo)
    if prezzo.present?
      self.prezzo_in_cents = (BigDecimal(prezzo) * 100).to_i
    else
      self.prezzo_in_cents = 0
    end
  end

  def prezzo_suggerito
    if prezzo_suggerito_cents
      prezzo_suggerito_cents / 100.0
    else
      0.0
    end
  end

  def prezzo_suggerito=(prezzo)
    if prezzo.present?
      self.prezzo_suggerito_cents = (BigDecimal(prezzo) * 100).to_i
    else
      self.prezzo_suggerito_cents = 0
    end
  end

  def previous
    Current.user.libri.where("titolo < ?", titolo).order(titolo: :desc).first
  end

  def next
    Current.user.libri.where("titolo > ?", titolo).order(titolo: :asc).first
  end


  def self.scarico_fascicoli
    
    sql = <<-SQL
      SELECT DISTINCT fascicolo_id, fasc.titolo, fasc.codice_isbn, fasc.prezzo_in_cents as prezzo_cents, 50.0 as sconto, SUM(conf.adozioni_count) as quantita
      FROM confezione_righe cr
        INNER JOIN libri fasc ON fasc.id = cr.fascicolo_id
        INNER JOIN libri conf ON conf.id = cr.confezione_id
        INNER JOIN users ON conf.user_id = users.id
      WHERE users.id = #{Current.user.id}
      GROUP BY 1, 2, 3, 4, 5
      HAVING (SUM(conf.adozioni_count) > 0)
    SQL

    result = ActiveRecord::Base.connection.execute(sql)
    result
  end

  private

  def discipline_prosegui
    if disciplina.to_s.match?(/LIBRO DELLA PRIMA/i)
      [disciplina, "SUSSIDIARIO (1° BIENNIO)"]
    else
      [disciplina]
    end
  end

  # Lunghezza del prefisso comune fra due titoli normalizzati (per l'ordinamento
  # delle opzioni prosegui).
  def prefisso_comune(a, b)
    n = 0
    n += 1 while n < a.length && n < b.length && a[n] == b[n]
    n
  end

  has_many :saggi, dependent: :restrict_with_error

  has_many :qrcodes, as: :qrcodable, dependent: :destroy
  
  # Metodo di convenienza per ottenere il primo QR code o crearne uno nuovo
  def qr_code
    qrcodes.first || qrcodes.create(url: "https://example.com/libri/#{self.id}")
  end

end
