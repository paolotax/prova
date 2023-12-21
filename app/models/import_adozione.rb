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
    
  pg_search_scope :search_any_word,
                against: [ :DISCIPLINA, :TITOLO, :SOTTOTITOLO, :VOLUME, :EDITORE, :AUTORI, :CODICEISBN, :CODICESCUOLA ],
                using: {
                  tsearch: { any_word: false, prefix: true }
                }
  
  scope :elementari, -> { where(TIPOGRADOSCUOLA: "EE") }

  scope :di_reggio,  -> { where(CODICESCUOLA: 'RE'..'REZZ') }

end
