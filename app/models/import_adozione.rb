# == Schema Information
#
# Table name: import_adozioni
#
#  id              :bigint           not null, primary key
#  CODICESCUOLA    :string
#  ANNOCORSO       :string
#  SEZIONEANNO     :string
#  TIPOGRADOSCUOLA :string
#  COMBINAZIONE    :string
#  DISCIPLINA      :string
#  CODICEISBN      :string
#  AUTORI          :string
#  TITOLO          :string
#  SOTTOTITOLO     :string
#  VOLUME          :string
#  EDITORE         :string
#  PREZZO          :string
#  NUOVAADOZ       :string
#  DAACQUIST       :string
#  CONSIGLIATO     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class ImportAdozione < ApplicationRecord

  include Searchable

  search_on :TITOLO, :EDITORE, :DISCIPLINA, import_scuola: [:CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :CODICEISTITUTORIFERIMENTO, :DENOMINAZIONEISTITUTORIFERIMENTO]


  belongs_to :import_scuola, foreign_key: "CODICESCUOLA", primary_key: "CODICESCUOLA"  
  belongs_to :editore,       foreign_key: "EDITORE",      primary_key: "EDITORE"

  belongs_to :classe, class_name: "Views::Classe", query_constraints: [:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA]

  has_many :user_scuole, through: :import_scuola
  has_many :users, through: :user_scuole

  has_many :tappe, as: :tappable

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
                
  scope :elementari, -> { where(TIPOGRADOSCUOLA: "EE") }

  scope :di_reggio,  -> { where(CODICESCUOLA: 'RE'..'REZZ') }

  scope :per_scuola_classe_sezione_disciplina, -> { order( :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA) }

  scope :per_scuola_classe_disciplina_sezione, -> { order( :CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :SEZIONEANNO) }
  
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

  scope :da_acquistare, -> { where(DAACQUIST: "Si") }

  scope :mie_adozioni, -> (user_editori = []) { where(EDITORE: user_editori) }

  

  def mia_adozione?(user_editori) 
    user_editori.include?(self.EDITORE)
  end

  def codice_ministeriale
    self.import_scuola.codice_ministeriale
  end

  def scuola
    self.import_scuola.scuola
  end

  def tipo_scuola
    self.import_scuola.tipo_scuola
  end

  def citta 
    self.import_scuola.citta
  end
 
  def anno
    self.ANNOCORSO
  end

  def classe
    self.ANNOCORSO
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

end
