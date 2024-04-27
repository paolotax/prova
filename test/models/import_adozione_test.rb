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
require "test_helper"

class ImportAdozioneTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
