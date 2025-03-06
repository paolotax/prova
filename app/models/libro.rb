# == Schema Information
#
# Table name: libri
#
#  id               :bigint           not null, primary key
#  adozioni_count   :integer          default(0), not null
#  categoria        :string
#  classe           :integer
#  codice_isbn      :string
#  confezioni_count :integer          default(0), not null
#  disciplina       :string
#  fascicoli_count  :integer          default(0), not null
#  note             :text
#  numero_fascicoli :integer
#  prezzo_in_cents  :integer
#  slug             :string
#  titolo           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  editore_id       :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_libri_on_classe_and_disciplina    (classe,disciplina)
#  index_libri_on_editore_id               (editore_id)
#  index_libri_on_slug                     (slug) UNIQUE
#  index_libri_on_user_id                  (user_id)
#  index_libri_on_user_id_and_categoria    (user_id,categoria)
#  index_libri_on_user_id_and_codice_isbn  (user_id,codice_isbn)
#  index_libri_on_user_id_and_editore_id   (user_id,editore_id)
#  index_libri_on_user_id_and_titolo       (user_id,titolo)
#
# Foreign Keys
#
#  fk_rails_...  (editore_id => editori.id)
#  fk_rails_...  (user_id => users.id)
#
class Libro < ApplicationRecord

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
  search_on :titolo, :codice_isbn, :disciplina, :note, :categoria, editore: :editore

  extend FilterableModel
  class << self
    def filter_proxy = Filters::LibroFilterProxy
  end

  include PgSearch::Model  
  search_fields =  [ :titolo, :disciplina, :codice_isbn, :categoria, :note ]
  pg_search_scope :search_all_word, 
                        against: search_fields,
                        associated_against: {
                          editore: [:editore]
                        },
                        using: {
                          tsearch: { any_word: false, prefix: true }
                        }

  belongs_to :user
  belongs_to :editore, optional: true
  
  has_one :giacenza, class_name: "Views::Giacenza", primary_key: "id", foreign_key: "libro_id"
  
  has_many :confezione_righe, foreign_key: "confezione_id", class_name: "ConfezioneRiga"
  has_many :fascicoli, through: :confezione_righe, dependent: :destroy

  has_many :fascicolo_righe, foreign_key: "fascicolo_id", class_name: "ConfezioneRiga"
  has_many :confezioni, through: :fascicolo_righe, dependent: :destroy
  
  accepts_nested_attributes_for :confezione_righe

  has_many :adozioni
  has_many :righe
  has_many :documenti, through: :righe
  has_many :documento_righe, through: :righe

  validates :titolo, presence: true
  #validates :editore, presence: true
  
  validates :prezzo_in_cents, presence: true
  
  has_many :user_adozioni, -> {
    Current.user.import_adozioni.da_acquistare.joins(:libro)
  }, class_name: "ImportAdozione", foreign_key: "CODICEISBN",  primary_key: "codice_isbn"
  
  validates :codice_isbn, presence: true, uniqueness: { scope: :user_id }

  has_many :import_adozioni, foreign_key: "CODICEISBN",  primary_key: "codice_isbn"
  
  scope :no_fascicoli, -> { where(fascicoli_count: 0) }
  scope :no_confezioni, -> { where(confezioni_count: 0) }
  scope :with_fascicoli, -> { where("fascicoli_count > 0") }
  scope :with_confezioni, -> { where("confezioni_count > 0") }

  scope :lista, -> { where("confezioni_count = 0 or fascicoli_count > 0") }
  
  before_save :init
  def init
    self.prezzo_in_cents ||= 0
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
    order(:categoria).distinct.pluck(:categoria).compact
  end

  def to_combobox_display
    self.titolo
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

  def previous
    Current.user.libri.where("titolo < ?", titolo).order(titolo: :desc).first
  end

  def next
    Current.user.libri.where("titolo > ?", titolo).order(titolo: :asc).first
  end


  # DA RIVEDERE

  def self.crosstab
    
    # Costruisci la lista delle causali
    causali = Causale.order(:magazzino, :movimento, :tipo_movimento).all.map(&:causale)

    # Costruisci la query dinamica
    crosstab_query = <<-SQL
      WITH situazio AS (
        SELECT *
        FROM crosstab(
          $$
          SELECT libri.id, causali.causale, sum(righe.quantita) as quantita
          FROM libri
                  JOIN righe ON righe.libro_id = libri.id
                  JOIN documento_righe on righe.id = documento_righe.riga_id
                  JOIN documenti on documento_righe.documento_id = documenti.id
                  JOIN causali on documenti.causale_id = causali.id
                  JOIN users on documenti.user_id = users.id 
          WHERE users.id = #{Current.user.id}
          GROUP BY 1, 2
          ORDER BY 1
          $$, $$
          SELECT causali.causale
          FROM causali ORDER BY causali.magazzino, causali.movimento, causali.tipo_movimento
          $$
        ) AS ct (id bigint, #{causali.map { |c| "#{c.gsub(' ', '_')} bigint" }.join(', ')})
      ) 
      SELECT 
        libri.codice_isbn, libri.titolo, libri.prezzo_in_cents, situazio.*, 
        editori.gruppo, editori.editore, libri.adozioni_count, libri.categoria, libri.classe, libri.disciplina, libri.id
      FROM libri
      INNER JOIN situazio ON libri.id = situazio.id
      INNER JOIN editori ON editori.id =  libri.editore_id
    SQL

    result = ActiveRecord::Base.connection.execute(crosstab_query)
    result
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

  has_one_attached :copertina
  
  def avatar_url
    if copertina.attached?
      copertina
    else
      # Restituisce le prime due iniziali del titolo
      iniziali = titolo.split.map(&:first).join[0..1].upcase
      "https://ui-avatars.com/api/?name=#{iniziali}&color=7F9CF5&background=EBF4FF"
    end
  end

  def qr_code(size = 120)
    qrcode = RQRCode::QRCode.new(self.url || "https://example.com/libri/#{self.id}")
    qrcode.as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: size / qrcode.modules.size,
      standalone: true
    ).html_safe
  end

end
