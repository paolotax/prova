# == Schema Information
#
# Table name: new_adozioni
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
#  scuola_id       :bigint
#
# Indexes
#
#  index_new_adozioni_on_classe  (anno_scolastico,CODICESCUOLA,ANNOCORSO,SEZIONEANNO,COMBINAZIONE,CODICEISBN) UNIQUE
#
class NewAdozione < ApplicationRecord
end
