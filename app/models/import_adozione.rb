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

  include PgSearch::Model
  
  search_fields =  [ :DISCIPLINA, :TITOLO, :SOTTOTITOLO, :VOLUME, :EDITORE, :AUTORI, :CODICEISBN, :CODICESCUOLA, :PREZZO ]

  pg_search_scope :search_all_word,
                against: search_fields,
                using: {
                  tsearch: { any_word: true, prefix: true }
                }
  
  scope :elementari, -> { where(TIPOGRADOSCUOLA: "EE") }

  scope :di_reggio,  -> { where(CODICESCUOLA: 'RE'..'REZZ') }

  scope :per_scuola_classe_sezione_disciplina, -> { order( :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA) }

  scope :per_scuola_classe_disciplina_sezione, -> { order( :CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :SEZIONEANNO) }

end
