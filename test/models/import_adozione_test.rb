# == Schema Information
#
# Table name: import_adozioni
#
#  id              :integer          not null, primary key
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
#  anno_scolastico :string
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
