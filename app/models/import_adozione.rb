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

  belongs_to :import_scuola, foreign_key: "CODICESCUOLA", primary_key: "CODICESCUOLA"

  include PgSearch::Model
  
  search_fields =  [ :TITOLO, :EDITORE, :DISCIPLINA, :AUTORI, :ANNOCORSO, :CODICEISBN, :CODICESCUOLA, :PREZZO ]

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

  scope :da_acquistare, -> { where(DAACQUIST: "Si") }


  def scuola
    self.import_scuola.DENOMINAZIONESCUOLA
  end

  def citta 
    self.import_scuola.DESCRIZIONECOMUNE
  end
 
  def to_s

    "#{self.TITOLO} - #{self.AUTORI} - #{self.EDITORE} - #{self.CODICEISBN}"

  end

end
