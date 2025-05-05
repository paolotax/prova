# == Schema Information
#
# Table name: new_scuole
#
#  id                                 :integer          not null, primary key
#  anno_scolastico                    :string
#  area_geografica                    :string
#  regione                            :string
#  provincia                          :string
#  codice_istituto_riferimento        :string
#  denominazione_istituto_riferimento :string
#  codice_scuola                      :string
#  denominazione                      :string
#  indirizzo                          :string
#  cap                                :string
#  codice_comune                      :string
#  comune                             :string
#  descrizione_caratteristica         :string
#  tipo_scuola                        :string
#  indicazione_sede_direttivo         :string
#  indicazione_sede_omnicomprensivo   :string
#  email                              :string
#  pec                                :string
#  sito_web                           :string
#  sede_scolastica                    :string
#  import_scuola_id                   :integer
#
# Indexes
#
#  index_new_scuole_on_codice_scuola  (anno_scolastico,codice_scuola) UNIQUE
#

require "test_helper"

class NewScuolaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
