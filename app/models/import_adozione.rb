# == Schema Information
#
# Table name: import_adozioni
#
#  id              :bigint           not null, primary key
#  ANNOCORSO       :string
#  AUTORI          :string
#  CODICEISBN      :string
#  CODICESCUOLA    :string
#  COMBINAZIONE    :string
#  CONSIGLIATO     :string
#  DAACQUIST       :string
#  DISCIPLINA      :string
#  EDITORE         :string
#  NUOVAADOZ       :string
#  PREZZO          :string
#  SEZIONEANNO     :string
#  SOTTOTITOLO     :string
#  TIPOGRADOSCUOLA :string
#  TITOLO          :string
#  VOLUME          :string
#  anno_scolastico :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  import_adozioni_pk                   (CODICESCUOLA,ANNOCORSO,SEZIONEANNO,TIPOGRADOSCUOLA,COMBINAZIONE,CODICEISBN,NUOVAADOZ,DAACQUIST,CONSIGLIATO) UNIQUE
#  index_import_adozioni_on_DISCIPLINA  (DISCIPLINA)
#  index_import_adozioni_on_EDITORE     (EDITORE)
#  index_import_adozioni_on_TITOLO      (TITOLO)
#
class ImportAdozione < ApplicationRecord

  include Searchable
  search_on :TITOLO, :EDITORE, :DISCIPLINA, import_scuola: [:CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :CODICEISTITUTORIFERIMENTO, :DENOMINAZIONEISTITUTORIFERIMENTO]

  extend FilterableModel
  class << self
    def filter_proxy = Filters::ImportAdozioneFilterProxy
  end

  belongs_to :import_scuola, foreign_key: "CODICESCUOLA", primary_key: "CODICESCUOLA"  
  belongs_to :editore,       foreign_key: "EDITORE",      primary_key: "EDITORE"

  has_one :classe, class_name: "Views::Classe", 
                  primary_key: [:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE],
                  query_constraints: [:codice_ministeriale, :classe, :sezione, :combinazione]

  has_many :user_scuole, through: :import_scuola
  has_many :users, through: :user_scuole

  has_many :saggi,  -> { where(nome: "saggio") },   class_name: "Appunto", foreign_key: "import_adozione_id"
  has_many :seguiti, -> { where(nome: "seguito") }, class_name: "Appunto", foreign_key: "import_adozione_id"
  has_many :kit,     -> { where(nome: "kit") },     class_name: "Appunto", foreign_key: "import_adozione_id"

  has_many :tappe, as: :tappable

  #has_many :appunti, dependent: :nullify
  #has_many :adozioni, dependent: :nullify

  has_one :libro, -> { where( user_id: Current.user.id) }, foreign_key: "codice_isbn", primary_key: "CODICEISBN"
  
  include PgSearch::Model  
  search_fields =  [ :TITOLO, :EDITORE, :DISCIPLINA, :AUTORI, :ANNOCORSO, :CODICEISBN, :CODICESCUOLA, :PREZZO ]

  pg_search_scope :search_combobox,
                        against: [:ANNOCORSO, :SEZIONEANNO, :TITOLO, :EDITORE, :DISCIPLINA],
                        associated_against: {
                          import_scuola: [:DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE]
                        },
                        using: {
                          tsearch: { any_word: false, prefix: true }
                        }

  pg_search_scope :search_all_word, 
                        against: search_fields,
                        associated_against: {
                          import_scuola: [:DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE]
                        },
                        using: {
                          tsearch: { any_word: false, prefix: true }
                        }
  
  pg_search_scope :search_any_word,
                          against: search_fields,
                          associated_against: {
                            import_scuola: [:DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE]
                          },
                          using: {
                            tsearch: { any_word: true, prefix: true }
                          }
                                          
  scope :per_scuola_classe_sezione_disciplina, -> { order( :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA) }

  scope :per_scuola_classe_disciplina_sezione, -> { order( :CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :SEZIONEANNO) }
  
  scope :classi_che_adottano, -> { where(ANNOCORSO: [3, 5]) }

  scope :raggruppate, -> { 
    order([:ANNOCORSO, :DISCIPLINA, :TITOLO, :CODICEISBN, :EDITORE])
    .group(:ANNOCORSO, :DISCIPLINA, :TITOLO, :CODICEISBN, :EDITORE)
    .select(:ANNOCORSO, :DISCIPLINA, :TITOLO, :CODICEISBN, :EDITORE)
    .select("ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids")
    .select("COUNT(import_adozioni.id) as numero_sezioni") 
  }

  scope :grouped_titolo, -> { 
    order(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :CODICEISBN, :TITOLO, :EDITORE)
    .group(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :CODICEISBN, :TITOLO, :EDITORE)
    .select(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :CODICEISBN, :TITOLO, :EDITORE)
    .select("ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids") 
    .select("ARRAY_AGG(import_adozioni.\"SEZIONEANNO\") AS import_adozioni_sezioni")
    .select("ARRAY_AGG(import_adozioni.\"COMBINAZIONE\") AS import_adozioni_combinazione")
  }

  scope :grouped_classe, -> { 
    order(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)
    .group(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)
    .select(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)
    .select("ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids")
  }
  
  scope :mie_adozioni, -> { where(EDITORE: Current.user.miei_editori) }
  scope :nel_baule_di_oggi, -> { where(CODICESCUOLA: ImportScuola.select(:CODICESCUOLA).distinct.where( id: Current.user.tappe.di_oggi.where(tappable_type: "ImportScuola").pluck(:tappable_id))) }  
  scope :nel_baule_di_domani, -> { where(CODICESCUOLA: ImportScuola.select(:CODICESCUOLA).distinct.where( id: Current.user.tappe.di_domani.where(tappable_type: "ImportScuola").pluck(:tappable_id))) } 

  
  def mia_adozione?
    Current.user.miei_editori.include?(self.EDITORE)
  end


  delegate :codice_ministeriale, :scuola, :citta, :tipo_scuola, :tipo_nome, to: :import_scuola
  

  def to_s 
    "#{self.classe_e_sezione} - #{self.titolo} - #{self.editore}"
  end

  def anno
    self.ANNOCORSO
  end

  # def classe
  #   self.ANNOCORSO
  # end

  def codice_scuola
    self.CODICESCUOLA
  end
  
  def classe_e_sezione 
    "#{self.ANNOCORSO} #{sezione}"
  end

  def classe_e_combinazione
    "#{self.ANNOCORSO} #{sezione} #{self.COMBINAZIONE.downcase}"
  end

  def sezione
    self.SEZIONEANNO.titleize
  end

  def disciplina
    self.DISCIPLINA.titleize
  end

  def combinazione
    self.COMBINAZIONE.downcase
  end

  def titolo
    ApplicationController.helpers.titleize_con_apostrofi self.TITOLO
  end

  def autori
    ApplicationController.helpers.titleize_con_apostrofi self.AUTORI
  end

  def editore
    self.EDITORE.upcase
  end

  def codice_isbn
    self.CODICEISBN
  end

  def prezzo
    self.PREZZO
  end

  def nuova_adozione
    self.NUOVAADOZ
  end

  def da_acquistare
    self.DAACQUIST
  end

  def consigliato
    self.CONSIGLIATO
  end


  def to_combobox_display
    "#{self.scuola} #{self.citta} - #{self.classe_e_sezione} - #{self.titolo} #{self.editore}"
  end

  def ssk
    self.appunti
      .joins(:import_adozione)
      .select("import_adozioni.id,
        count(CASE WHEN appunti.nome = 'saggio' THEN appunti.nome END ) AS saggi,
        array_agg(CASE WHEN appunti.nome = 'saggio' THEN appunti.id END) AS saggi_ids,

        count(CASE WHEN appunti.nome = 'seguito' THEN appunti.nome END ) AS seguiti,
        array_agg(CASE WHEN appunti.nome = 'seguito' THEN appunti.id END) AS seguiti_ids,

        count(CASE WHEN appunti.nome = 'kit' THEN  appunti.id END ) AS kit,
        array_agg(CASE WHEN appunti.nome = 'kit' THEN appunti.id END) AS kit_ids")
      .group("import_adozioni.id")
  end



  def self.import_new_adozioni
    
    count = 0
    a = []
    NewAdozione.find_each(batch_size: 10_000) do |new_adozione|
      
      a << ImportAdozione.new(
        anno_scolastico: '202425',      
        ANNOCORSO: new_adozione.annocorso,
        AUTORI: new_adozione.autori,
        CODICEISBN: new_adozione.codiceisbn,
        CODICESCUOLA: new_adozione.codicescuola,
        COMBINAZIONE: new_adozione.combinazione,
        CONSIGLIATO: new_adozione.consigliato,
        DAACQUIST: new_adozione.daacquist,
        DISCIPLINA: new_adozione.disciplina,
        EDITORE: new_adozione.editore,
        NUOVAADOZ: new_adozione.nuovaadoz,
        PREZZO: new_adozione.prezzo,
        SEZIONEANNO: new_adozione.sezioneanno,
        SOTTOTITOLO: new_adozione.sottotitolo,
        TIPOGRADOSCUOLA: new_adozione.tipogradoscuola,
        TITOLO: new_adozione.titolo,
        VOLUME: new_adozione.volume
      )
      count += 1
      if count >= 10000
        ImportAdozione.import a, on_duplicate_key_ignore: true 
        count = 0
        a = []
      end    
    end
    ImportAdozione.import a, on_duplicate_key_ignore: true if a.present?

    Scenic.database.refresh_materialized_view("view_classi", concurrently: false, cascade: false)
    
  end

end
